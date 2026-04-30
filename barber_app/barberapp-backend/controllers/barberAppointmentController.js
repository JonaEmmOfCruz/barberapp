const Appointment = require('../models/barberAppointment');
const Barber = require('../models/barberos');
const AgendaSlot = require('../models/barberAgendaSlot');
const mongoose = require('mongoose');



// ── Helper: calcular distancia con Google Directions API ──────────
async function calcularDistancia(origenLat, origenLng, destinoLat, destinoLng) {
    try {
        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${origenLat},${origenLng}&destination=${destinoLat},${destinoLng}&key=${apiKey}`;
        
        const response = await fetch(url);
        const data     = await response.json();
        
        if (data.status === 'OK' && data.routes.length > 0) {
            const distanciaMetros = data.routes[0].legs[0].distance.value;
            return Math.round(distanciaMetros / 100) / 10; // km con 1 decimal
        }
        return null;
    } catch (e) {
        console.error('Error Google Directions:', e);
        return null;
    }
}

exports.startTrip = async (req, res) => {
    try {
        const { idCita } = req.params;
        const cita = await Appointment.findByIdAndUpdate(
            idCita,
            { status: 'en_camino', horaSalida: new Date() },
            { new: true }
        );
        if (!cita) return res.status(404).json({ success: false, msg: "Cita no encontrada" });
        await Barber.findByIdAndUpdate(cita.barberId, { isWorking: true });
        res.status(200).json({ success: true, msg: "Viaje iniciado. El barbero está en camino.", data: cita });
    } catch (error) {
        console.error("Error en startTrip:", error);
        res.status(500).json({ success: false, msg: "Error al procesar el inicio del viaje" });
    }
};

exports.arriveAtDestination = async (req, res) => {
    try {
        const { idCita } = req.params;
        const cita = await Appointment.findByIdAndUpdate(
            idCita,
            { horaLlegada: new Date() },
            { new: true }
        );
        if (!cita) return res.status(404).json({ success: false, msg: "Cita no encontrada" });
        res.status(200).json({ success: true, msg: "Llegada registrada por GPS.", horaLlegada: cita.horaLlegada });
    } catch (error) {
        console.error("Error en arriveAtDestination:", error);
        res.status(500).json({ success: false, msg: "Error al registrar llegada" });
    }
};

exports.finishService = async (req, res) => {
    try {
        const { idCita } = req.params;
        const cita = await Appointment.findByIdAndUpdate(
            idCita,
            { status: 'finalizada', horaFin: new Date() },
            { new: true }
        );
        if (!cita) return res.status(404).json({ success: false, msg: "Cita no encontrada" });
        await Barber.findByIdAndUpdate(cita.barberId, { isWorking: false });
        const duracionTotal = Math.round((cita.horaFin - cita.horaSalida) / 60000);
        res.status(200).json({ success: true, msg: "Servicio finalizado y barbero liberado.", duracionMinutos: duracionTotal, data: cita });
    } catch (error) {
        console.error("Error en finishService:", error);
        res.status(500).json({ success: false, msg: "Error al finalizar el servicio" });
    }
};

// ─────────────────────────────────────────────
//  NUEVOS ENDPOINTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────
//  getCitasBarbero
//  GET /api/citas/barbero/:barberId?fecha=YYYY-MM-DD
//
//  Devuelve todas las citas del barbero para una fecha específica.
//  Flutter lo llama al seleccionar un día en el selector semanal.
// ─────────────────────────────────────────────────────────────────────
exports.getCitasBarbero = async (req, res) => {
    try {
        const { barberId } = req.params;
        const { fecha }    = req.query;

        if (!fecha) {
            return res.status(400).json({ success: false, msg: 'Falta el parámetro fecha' });
        }

        const db = require('mongoose').connection.db;

        const reservas = await db.collection('userReservas').find({
            barberId: new mongoose.Types.ObjectId(barberId),
            fecha:    fecha,
            status: { $in: ['aceptada', 'en_camino', 'en_proceso'] }
        }).sort({ hora: 1 }).toArray();

        // Obtener ubicación actual del barbero
        const barberoDoc = await db.collection('barberos').findOne(
            { _id: new mongoose.Types.ObjectId(barberId) },
            { projection: { lastLocation: 1 } }
        );
        const barberoLat = barberoDoc?.lastLocation?.lat;
        const barberoLng = barberoDoc?.lastLocation?.lng;

        const citasNormalizadas = await Promise.all(
            reservas.map(async (r) => {
                const cliente = await db.collection('users').findOne(
                    { _id: r.userId },
                    { projection: { nombre: 1 } }
                );

                // Calcular distancia si tenemos las coordenadas
                let distanciaKm = null;
                if (barberoLat && barberoLng && r.lat && r.lng) {
                    distanciaKm = await calcularDistancia(barberoLat, barberoLng, r.lat, r.lng);
                }

                return {
                    _id:           r._id,
                    clienteNombre: cliente?.nombre ?? 'Cliente',
                    clienteFoto:   null,
                    domicilio:     r.domicilio ?? '',
                    distanciaKm,
                    servicios:     Array.isArray(r.servicios) ? r.servicios.join(', ') : 'Cita agendada',
                    hora:          r.hora,
                    fecha:         r.fecha,
                    precioTotal:   0,
                    status:        r.status,
                    lat:           r.lat ?? null,
                    lng:           r.lng ?? null,
                };
            })
        );

        res.status(200).json({
            success: true,
            fecha,
            total: citasNormalizadas.length,
            citas: citasNormalizadas
        });

    } catch (error) {
        console.error('Error getCitasBarbero:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};

// ─────────────────────────────────────────────────────────────────────
//  responderSolicitud
//  PUT /api/citas/:idCita/responder
//  Body: { accion: 'aceptar' | 'rechazar' | 'reagendar', nuevaHora?: 'HH:MM', nuevaFecha?: 'YYYY-MM-DD' }
//
//  El barbero acepta, rechaza o propone reagendar una cita.
// ─────────────────────────────────────────────────────────────────────
exports.responderSolicitud = async (req, res) => {
    try {
        const { idCita } = req.params;
        const { accion, nuevaHora, nuevaFecha } = req.body;

        if (!['aceptar', 'rechazar', 'reagendar', 'llegar', 'finalizar'].includes(accion)) {
            return res.status(400).json({ success: false, msg: 'Acción inválida' });
        }

        const db = require('mongoose').connection.db;
        const reserva = await db.collection('userReservas').findOne({
            _id: new mongoose.Types.ObjectId(idCita)
        });

        if (!reserva) {
            return res.status(404).json({ success: false, msg: 'Cita no encontrada' });
        }

        if (accion === 'aceptar') {
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'aceptada' } }
            );
            res.status(200).json({ success: true, msg: 'Cita aceptada' });

        } else if (accion === 'rechazar') {
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'rechazada' } }
            );
            await AgendaSlot.findOneAndUpdate(
                { barberId: reserva.barberId, fecha: reserva.fecha, hora: reserva.hora },
                { $set: { status: 'disponible', appointmentId: null, clientId: null } }
            );
            res.status(200).json({ success: true, msg: 'Cita rechazada' });

        } else if (accion === 'reagendar') {
            if (!nuevaHora || !nuevaFecha) {
                return res.status(400).json({ success: false, msg: 'Falta nuevaHora o nuevaFecha' });
            }
            const slotNuevo = await AgendaSlot.findOne({
                barberId: reserva.barberId,
                fecha:    nuevaFecha,
                hora:     nuevaHora,
                status:   'disponible'
            });
            if (!slotNuevo) {
                return res.status(400).json({ success: false, msg: 'El horario propuesto no está disponible' });
            }
            await AgendaSlot.findOneAndUpdate(
                { barberId: reserva.barberId, fecha: reserva.fecha, hora: reserva.hora },
                { $set: { status: 'disponible', appointmentId: null, clientId: null } }
            );
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'reagendada', hora: nuevaHora, fecha: nuevaFecha } }
            );
            await AgendaSlot.findByIdAndUpdate(slotNuevo._id, {
                $set: { status: 'ocupado', appointmentId: reserva._id, clientId: reserva.userId }
            });
            res.status(200).json({ success: true, msg: `Reagendada para ${nuevaFecha} a las ${nuevaHora}` });

        } else if (accion === 'llegar') {
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'en_proceso' } }
            );
            res.status(200).json({ success: true, msg: 'Llegada registrada' });

        } else if (accion === 'finalizar') {
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'completada' } }
            );
            await AgendaSlot.findOneAndUpdate(
                { barberId: reserva.barberId, fecha: reserva.fecha, hora: reserva.hora },
                { $set: { status: 'pasado', appointmentId: null, clientId: null } }
            );
            await Barber.findByIdAndUpdate(reserva.barberId, { isWorking: false });
            res.status(200).json({ success: true, msg: 'Servicio finalizado' });
        }

    } catch (error) {
        console.error('Error responderSolicitud:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};
exports.getPendientes = async (req, res) => {
    try {
        const { barberId } = req.params;
        const db = require('mongoose').connection.db;

        const pendientes = await db.collection('userReservas').find({
            barberId: new mongoose.Types.ObjectId(barberId),
            status:   'pendiente'
        }).sort({ createdAt: 1 }).toArray();

        const enriquecidas = await Promise.all(
            pendientes.map(async (r) => {
                const cliente = await db.collection('users').findOne(
                    { _id: r.userId },
                    { projection: { nombre: 1, telefono: 1 } }
                );
                return {
                    _id:           r._id,
                    clienteNombre: cliente?.nombre   ?? 'Cliente',
                    clienteTel:    cliente?.telefono ?? '',
                    servicios:     Array.isArray(r.servicios) ? r.servicios : [],
                    hora:          r.hora,
                    fecha:         r.fecha,
                    status:        r.status,
                };
            })
        );

        res.status(200).json({
            success:   true,
            pendientes: enriquecidas
        });

    } catch (error) {
        console.error('Error getPendientes:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};