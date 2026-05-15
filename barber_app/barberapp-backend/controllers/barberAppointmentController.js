const Barber     = require('../models/barberos');
const AgendaSlot = require('../models/barberAgendaSlot');
const mongoose   = require('mongoose');

// ── Helper: calcular distancia con Google Directions API ──────────
async function calcularDistancia(origenLat, origenLng, destinoLat, destinoLng) {
    try {
        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        const url    = `https://maps.googleapis.com/maps/api/directions/json?origin=${origenLat},${origenLng}&destination=${destinoLat},${destinoLng}&key=${apiKey}`;
        const response = await fetch(url);
        const data     = await response.json();
        if (data.status === 'OK' && data.routes.length > 0) {
            const distanciaMetros = data.routes[0].legs[0].distance.value;
            return Math.round(distanciaMetros / 100) / 10;
        }
        return null;
    } catch (e) {
        console.error('Error Google Directions:', e);
        return null;
    }
}

// ── Helpers de tiempo ─────────────────────────────────────────────
function horaAMinutos(hora) {
    const [h, m] = hora.split(':').map(Number);
    return h * 60 + m;
}

function minutosAHora(minutos) {
    const h = Math.floor(minutos / 60).toString().padStart(2, '0');
    const m = (minutos % 60).toString().padStart(2, '0');
    return `${h}:${m}`;
}

// ─────────────────────────────────────────────────────────────────
exports.startTrip = async (req, res) => {
    try {
        const { idCita } = req.params;
        const cita = await Appointment.findByIdAndUpdate(
            idCita,
            { status: 'en_camino', horaSalida: new Date() },
            { new: true }
        );
        if (!cita) return res.status(404).json({ success: false, msg: 'Cita no encontrada' });
        await Barber.findByIdAndUpdate(cita.barberId, { isWorking: true });
        res.status(200).json({ success: true, msg: 'Viaje iniciado.', data: cita });
    } catch (error) {
        console.error('Error en startTrip:', error);
        res.status(500).json({ success: false, msg: 'Error al procesar el inicio del viaje' });
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
        if (!cita) return res.status(404).json({ success: false, msg: 'Cita no encontrada' });
        res.status(200).json({ success: true, msg: 'Llegada registrada por GPS.', horaLlegada: cita.horaLlegada });
    } catch (error) {
        console.error('Error en arriveAtDestination:', error);
        res.status(500).json({ success: false, msg: 'Error al registrar llegada' });
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
        if (!cita) return res.status(404).json({ success: false, msg: 'Cita no encontrada' });
        await Barber.findByIdAndUpdate(cita.barberId, { isWorking: false });
        const duracionTotal = Math.round((cita.horaFin - cita.horaSalida) / 60000);
        res.status(200).json({ success: true, msg: 'Servicio finalizado.', duracionMinutos: duracionTotal, data: cita });
    } catch (error) {
        console.error('Error en finishService:', error);
        res.status(500).json({ success: false, msg: 'Error al finalizar el servicio' });
    }
};

// ─────────────────────────────────────────────────────────────────
//  getCitasBarbero
// ─────────────────────────────────────────────────────────────────
exports.getCitasBarbero = async (req, res) => {
    try {
        const { barberId } = req.params;
        const { fecha }    = req.query;
        if (!fecha) return res.status(400).json({ success: false, msg: 'Falta el parámetro fecha' });

        const db = require('mongoose').connection.db;

        const reservas = await db.collection('userReservas').find({
            barberId: new mongoose.Types.ObjectId(barberId),
            fecha,
            status: { $in: ['aceptada', 'en_camino', 'en_proceso'] }
        }).sort({ hora: 1 }).toArray();

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
                    { projection: { nombre: 1, profileImage: 1 } }
                );
                let distanciaKm = null;
                if (barberoLat && barberoLng && r.lat && r.lng) {
                    distanciaKm = await calcularDistancia(barberoLat, barberoLng, r.lat, r.lng);
                }
                return {
                    _id:           r._id,
                    clienteNombre: cliente?.nombre        ?? 'Cliente',
                    clienteFoto:   cliente?.profileImage  ?? null,
                    domicilio:     r.domicilio            ?? '',
                    distanciaKm,
                    servicios:     Array.isArray(r.servicios) ? r.servicios.join(', ') : 'Cita agendada',
                    hora:          r.hora,
                    fecha:         r.fecha,
                    precioTotal:   r.costoTotal           ?? 0,
                    status:        r.status,
                    lat:           r.lat                  ?? null,
                    lng:           r.lng                  ?? null,
                };
            })
        );

        res.status(200).json({ success: true, fecha, total: citasNormalizadas.length, citas: citasNormalizadas });
    } catch (error) {
        console.error('Error getCitasBarbero:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};

// ─────────────────────────────────────────────────────────────────
//  responderSolicitud
// ─────────────────────────────────────────────────────────────────
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
        if (!reserva) return res.status(404).json({ success: false, msg: 'Cita no encontrada' });

        // ── ACEPTAR ───────────────────────────────────────────────
        if (accion === 'aceptar') {
            const BarberDisponibilidad = require('../models/barberDisponibilidad');

            const disp     = await BarberDisponibilidad.findOne({ barberId: reserva.barberId });
            const slotBase = disp?.duracionSlotMin ?? 30;
            let duracionServicio = 0;

            if (disp?.duracionPorServicio?.length > 0 && Array.isArray(reserva.servicios)) {
                for (const svc of reserva.servicios) {
                    const found = disp.duracionPorServicio.find(
                        d => d.nombre.toLowerCase() === svc.toLowerCase());
                    if (found) duracionServicio += found.duracionMin;
                }
            }
            if (duracionServicio === 0) duracionServicio = slotBase;

            let tiempoTraslado = 0;
            const barberoDoc = await db.collection('barberos').findOne(
                { _id: reserva.barberId },
                { projection: { lastLocation: 1 } }
            );
            if (barberoDoc?.lastLocation?.lat && reserva.lat && reserva.lng) {
                try {
                    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
                    const url    = `https://maps.googleapis.com/maps/api/directions/json?origin=${barberoDoc.lastLocation.lat},${barberoDoc.lastLocation.lng}&destination=${reserva.lat},${reserva.lng}&key=${apiKey}`;
                    const resp   = await fetch(url);
                    const data   = await resp.json();
                    if (data.status === 'OK') {
                        tiempoTraslado = Math.ceil(data.routes[0].legs[0].duration.value / 60);
                    }
                } catch (_) {}
            }

            const duracionTotal  = duracionServicio + tiempoTraslado;
            const horaInicioMin  = horaAMinutos(reserva.hora);
            const slotsABloquear = [];

            for (let min = horaInicioMin; min < horaInicioMin + duracionTotal; min += slotBase) {
                slotsABloquear.push(minutosAHora(min));
            }

            for (const hora of slotsABloquear) {
                await AgendaSlot.findOneAndUpdate(
                    { barberId: reserva.barberId, fecha: reserva.fecha, hora },
                    { $set: { status: 'ocupado', appointmentId: reserva._id, clientId: reserva.userId } },
                    { upsert: true }
                );
            }

            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'aceptada', duracionServicio, tiempoTraslado, duracionTotal } }
            );

            res.status(200).json({ success: true, msg: 'Cita aceptada', slotsBlockeados: slotsABloquear, duracionTotal });

        // ── RECHAZAR ──────────────────────────────────────────────
        } else if (accion === 'rechazar') {
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'rechazada' } }
            );
            await AgendaSlot.deleteMany({
                barberId:      reserva.barberId,
                fecha:         reserva.fecha,
                appointmentId: reserva._id
            });
            res.status(200).json({ success: true, msg: 'Cita rechazada' });

        // ── REAGENDAR ─────────────────────────────────────────────
        } else if (accion === 'reagendar') {
            if (!nuevaHora || !nuevaFecha) {
                return res.status(400).json({ success: false, msg: 'Falta nuevaHora o nuevaFecha' });
            }
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'reagendada', hora: nuevaHora, fecha: nuevaFecha } }
            );
            res.status(200).json({ success: true, msg: `Reagendada para ${nuevaFecha} a las ${nuevaHora}` });

        // ── LLEGAR ────────────────────────────────────────────────
        } else if (accion === 'llegar') {
            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: { status: 'en_proceso', horaLlegada: new Date() } }
            );
            res.status(200).json({ success: true, msg: 'Llegada registrada' });

        // ── FINALIZAR ─────────────────────────────────────────────
        } else if (accion === 'finalizar') {
            const horaFin     = new Date();
            const horaLlegada = reserva.horaLlegada;

            // Calcular duración real
            let duracionReal = null;
            if (horaLlegada) {
                duracionReal = Math.round((horaFin - new Date(horaLlegada)) / 60000);
            }

            // Calcular precio real
            const { calcularPrecio } = require('../config/precios');
            const barbero       = await Barber.findById(reserva.barberId);
            const promedio      = barbero?.calificacion?.promedio     ?? 0;
            const totalResenias = barbero?.calificacion?.totalReseñas ?? 0;
            const distanciaKm   = reserva.distanciaKm ?? 1;

            const precio = calcularPrecio(
                reserva.servicios,
                distanciaKm,
                promedio,
                totalResenias,
            );

            await db.collection('userReservas').updateOne(
                { _id: reserva._id },
                { $set: {
                    status:         'completada',
                    horaFin,
                    duracionReal,
                    costoTotal:     precio.total,
                    desglosePrecio: precio,
                }}
            );

            // Actualizar promedio por combinación de servicios
            if (duracionReal && duracionReal > 0 && Array.isArray(reserva.servicios) && reserva.servicios.length > 0) {
                const clave = [...reserva.servicios].sort().join(',');
                if (barbero) {
                    const porTipo   = barbero.metricas?.porTipo || {};
                    const existente = porTipo[clave] || { cantidad: 0, promedioMin: 0 };
                    const nuevaCant = existente.cantidad + 1;
                    const nuevoPromedio = Math.round(
                        ((existente.promedioMin * existente.cantidad) + duracionReal) / nuevaCant
                    );
                    await Barber.findByIdAndUpdate(reserva.barberId, {
                        $inc: { 'metricas.totalServicios': 1 },
                        $set: {
                            [`metricas.porTipo.${clave}`]: {
                                cantidad:    nuevaCant,
                                promedioMin: nuevoPromedio,
                            }
                        }
                    });
                }
            }

            // Liberar slots
            await AgendaSlot.updateMany(
                { barberId: reserva.barberId, fecha: reserva.fecha, appointmentId: reserva._id },
                { $set: { status: 'pasado', appointmentId: null, clientId: null } }
            );
            await Barber.findByIdAndUpdate(reserva.barberId, { isWorking: false });

            res.status(200).json({
                success:        true,
                msg:            'Servicio finalizado',
                duracionReal,
                costoTotal:     precio.total,
                desglosePrecio: precio,
            });
        }

    } catch (error) {
        console.error('Error responderSolicitud:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};

// ─────────────────────────────────────────────────────────────────
//  getPendientes
// ─────────────────────────────────────────────────────────────────
exports.getPendientes = async (req, res) => {
    try {
        const { barberId } = req.params;
        const mongoose = require('mongoose');
        const db = mongoose.connection.readyState === 1
            ? mongoose.connection.db
            : null;

        if (!db) return res.status(503).json({ success: false, pendientes: [] });

        const BarberDisponibilidad = require('../models/barberDisponibilidad');

        const pendientes = await db.collection('userReservas').find({
            barberId: new mongoose.Types.ObjectId(barberId),
            status:   'pendiente'
        }).sort({ createdAt: 1 }).toArray();

        const disp     = await BarberDisponibilidad.findOne({ barberId });
        const slotBase = disp?.duracionSlotMin ?? 30;

        const enriquecidas = await Promise.all(
            pendientes.map(async (r) => {
                const cliente = await db.collection('users').findOne(
                    { _id: r.userId },
                    { projection: { nombre: 1, telefono: 1 } }
                );

                let duracionTotal = slotBase;
                if (disp?.duracionPorServicio?.length > 0 && Array.isArray(r.servicios)) {
                    let suma = 0;
                    for (const svc of r.servicios) {
                        const found = disp.duracionPorServicio.find(
                            d => d.nombre.toLowerCase() === svc.toLowerCase());
                        if (found) suma += found.duracionMin;
                    }
                    if (suma > 0) duracionTotal = suma;
                }

                // Verificar si hay promedio real disponible para esta combinación
                const barbero = await Barber.findById(barberId, { metricas: 1 });
                if (barbero?.metricas?.totalServicios >= 10) {
                    const clave     = [...r.servicios].sort().join(',');
                    const porTipo   = barbero.metricas?.porTipo;
                    const datoClave = porTipo && porTipo[clave];
                    if (datoClave?.cantidad >= 10) {
                        duracionTotal = datoClave.promedioMin;
                    }
                }

                let excedeHorario = false;
                if (disp && r.hora && r.fecha) {
                    const diaSemana = new Date(r.fecha + 'T12:00:00').getDay();
                    const diaConfig = disp.diasDisponibles?.find(d => d.dia === diaSemana);
                    if (diaConfig) {
                        const horaAMin   = (h) => { const [hh, mm] = h.split(':').map(Number); return hh * 60 + mm; };
                        const horaInicio = horaAMin(r.hora);
                        const horaFin    = horaAMin(diaConfig.finHora);
                        excedeHorario    = (horaInicio + duracionTotal) > horaFin;
                    }
                }

                return {
                    _id:           r._id,
                    clienteNombre: cliente?.nombre   ?? 'Cliente',
                    clienteTel:    cliente?.telefono ?? '',
                    servicios:     Array.isArray(r.servicios) ? r.servicios : [],
                    hora:          r.hora,
                    fecha:         r.fecha,
                    status:        r.status,
                    duracionTotal,
                    excedeHorario,
                };
            })
        );

        res.status(200).json({ success: true, pendientes: enriquecidas });
    } catch (error) {
        console.error('Error getPendientes:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};