const Appointment = require('../models/barberAppointment');
const Barber = require('../models/barberos');
const AgendaSlot = require('../models/barberAgendaSlot');
const mongoose = require('mongoose');

// ─────────────────────────────────────────────
//  LO QUE YA TENÍAS — SIN CAMBIOS
// ─────────────────────────────────────────────

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
        const { fecha } = req.query;

        if (!fecha) {
            return res.status(400).json({ success: false, msg: 'Falta el parámetro fecha' });
        }

        // Convertimos la fecha a rango de inicio y fin del día
        const inicioDia = new Date(`${fecha}T00:00:00.000Z`);
        const finDia    = new Date(`${fecha}T23:59:59.999Z`);

        const citas = await Appointment.find({
            barberId: new mongoose.Types.ObjectId(barberId),
            horaProgramada: { $gte: inicioDia, $lte: finDia },
            status: { $in: ['aceptada', 'en_camino', 'en_proceso', 'finalizada'] }
        }).sort({ horaProgramada: 1 });

        // Normalizamos para Flutter
        const citasNormalizadas = citas.map(c => ({
            _id:           c._id,
            clienteNombre: c.clienteNombre ?? 'Cliente',
            clienteFoto:   null, // se agrega cuando tengas la colección de usuarios
            domicilio:     c.domicilio ?? '',
            distanciaKm:   null, // se calcula con Google Directions cuando el barbero abre la cita
            servicios:     'Cita agendada', // se actualiza cuando el modelo tenga el campo
            hora:          c.horaProgramada
                ? new Date(c.horaProgramada).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', hour12: false })
                : '',
            fecha:         fecha,
            precioTotal:   c.precioTotal ?? 0,
            status:        c.status,
            lat:           c.lat ?? null,
            lng:           c.lng ?? null,
        }));

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

        if (!['aceptar', 'rechazar', 'reagendar'].includes(accion)) {
            return res.status(400).json({ success: false, msg: 'Acción inválida' });
        }

        const cita = await Appointment.findById(idCita);
        if (!cita) return res.status(404).json({ success: false, msg: 'Cita no encontrada' });

        if (accion === 'aceptar') {
            // Marcamos la cita como aceptada
            cita.status = 'aceptada';
            await cita.save();

            // Marcamos el slot como ocupado en agendaSlots
            if (cita.horaProgramada) {
                const fecha = cita.horaProgramada.toISOString().split('T')[0];
                const hora  = cita.horaProgramada.toLocaleTimeString('es-MX', {
                    hour: '2-digit', minute: '2-digit', hour12: false
                });
                await AgendaSlot.findOneAndUpdate(
                    { barberId: cita.barberId, fecha, hora },
                    { $set: { status: 'ocupado', appointmentId: cita._id, clientId: cita.clientId } }
                );
            }

            res.status(200).json({ success: true, msg: 'Cita aceptada', cita });

        } else if (accion === 'rechazar') {
            cita.status = 'rechazada';
            await cita.save();

            // Liberamos el slot
            if (cita.horaProgramada) {
                const fecha = cita.horaProgramada.toISOString().split('T')[0];
                const hora  = cita.horaProgramada.toLocaleTimeString('es-MX', {
                    hour: '2-digit', minute: '2-digit', hour12: false
                });
                await AgendaSlot.findOneAndUpdate(
                    { barberId: cita.barberId, fecha, hora },
                    { $set: { status: 'disponible', appointmentId: null, clientId: null } }
                );
            }

            res.status(200).json({ success: true, msg: 'Cita rechazada', cita });

        } else if (accion === 'reagendar') {
            if (!nuevaHora || !nuevaFecha) {
                return res.status(400).json({ success: false, msg: 'Falta nuevaHora o nuevaFecha para reagendar' });
            }

            // Verificamos que el nuevo slot esté disponible
            const slotNuevo = await AgendaSlot.findOne({
                barberId: cita.barberId,
                fecha:    nuevaFecha,
                hora:     nuevaHora,
                status:   'disponible'
            });

            if (!slotNuevo) {
                return res.status(400).json({ success: false, msg: 'El horario propuesto no está disponible' });
            }

            // Liberamos el slot anterior
            if (cita.horaProgramada) {
                const fechaAnterior = cita.horaProgramada.toISOString().split('T')[0];
                const horaAnterior  = cita.horaProgramada.toLocaleTimeString('es-MX', {
                    hour: '2-digit', minute: '2-digit', hour12: false
                });
                await AgendaSlot.findOneAndUpdate(
                    { barberId: cita.barberId, fecha: fechaAnterior, hora: horaAnterior },
                    { $set: { status: 'disponible', appointmentId: null, clientId: null } }
                );
            }

            // Actualizamos la cita con la nueva hora
            const nuevaHoraProgramada = new Date(`${nuevaFecha}T${nuevaHora}:00.000Z`);
            cita.horaProgramada = nuevaHoraProgramada;
            cita.status = 'reagendada'; // el cliente verá esto como "propuesta de cambio"
            await cita.save();

            // Ocupamos el nuevo slot
            await AgendaSlot.findByIdAndUpdate(slotNuevo._id, {
                $set: { status: 'ocupado', appointmentId: cita._id, clientId: cita.clientId }
            });

            res.status(200).json({ success: true, msg: `Cita reagendada para el ${nuevaFecha} a las ${nuevaHora}`, cita });
        }

    } catch (error) {
        console.error('Error responderSolicitud:', error);
        res.status(500).json({ success: false, msg: 'Error del servidor' });
    }
};