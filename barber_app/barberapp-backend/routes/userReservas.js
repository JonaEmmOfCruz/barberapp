const express = require('express');
const router  = express.Router();
const Appointment = require('../models/userReservas');
const AgendaSlot  = require('../models/barberAgendaSlot');

router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const db = require('mongoose').connection.db;
    const reservas = await Appointment.find({ userId }).sort({ fecha: -1 });
    const reservasConNombre = await Promise.all(
      reservas.map(async (r) => {
        const barbero = await db.collection('barberos').findOne(
          { _id: r.barberId },
          { projection: { nombre: 1 } }
        );
        return { ...r.toObject(), barberoNombre: barbero?.nombre ?? 'Barbero' };
      })
    );
    res.status(200).json(reservasConNombre);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener reservas' });
  }
});

router.post('/create', async (req, res) => {
  try {
   const { userId, barberId, fecha, hora, servicios, domicilio, lat, lng } = req.body;
    if (!userId || !barberId || !fecha || !hora) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }
    const slot = await AgendaSlot.findOne({ barberId, fecha, hora, status: 'disponible' });
    if (!slot) {
      return res.status(400).json({ error: 'El horario seleccionado ya no está disponible' });
    }
    const nuevaReserva = new Appointment({ userId, barberId, fecha, hora, servicios: servicios ?? [], domicilio: domicilio ?? '', lat: lat ?? null, lng: lng ?? null, status: 'pendiente' });
    const reservaGuardada = await nuevaReserva.save();
    await AgendaSlot.findByIdAndUpdate(slot._id, { status: 'ocupado', clientId: userId, appointmentId: reservaGuardada._id });
    res.status(201).json({ message: 'Cita creada, esperando confirmación del barbero', appointmentId: reservaGuardada._id, data: reservaGuardada });
  } catch (error) {
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const reserva = await Appointment.findById(req.params.id);
    if (!reserva) return res.status(404).json({ error: 'Reserva no encontrada' });
    res.json(reserva);
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

module.exports = router;