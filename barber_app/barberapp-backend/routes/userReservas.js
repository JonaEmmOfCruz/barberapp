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
        // Obtener foto del barbero
        const docs = await db.collection('barberDocuments').findOne(
          { barberId: r.barberId.toString() },
          { projection: { profileImage: 1 } }
        );
        return {
          ...r.toObject(),
          barberoNombre:  barbero?.nombre ?? 'Barbero',
          barberoFoto:    docs?.profileImage ?? null,
        };
      })
    );
    
    res.status(200).json(reservasConNombre);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener reservas' });
  }
});

router.post('/create', async (req, res) => {
  try {
    const { userId, barberId, fecha, hora, servicios, personas, domicilio, lat, lng } = req.body;
    if (!userId || !barberId || !fecha || !hora) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }

    // Verificar que el slot NO esté ocupado
    const slotOcupado = await AgendaSlot.findOne({ barberId, fecha, hora, status: 'ocupado' });
    if (slotOcupado) {
      return res.status(400).json({ error: 'El horario seleccionado ya no está disponible' });
    }

    // Crear la reserva
    const nuevaReserva = new Appointment({
      userId, barberId, fecha, hora,
      servicios:  servicios ?? [],
      personas:   personas  ?? [],
      domicilio:  domicilio ?? '',
      lat:        lat       ?? null,
      lng:        lng       ?? null,
      status:     'pendiente'
    });
    const reservaGuardada = await nuevaReserva.save();

    // Calcular duración total y bloquear todos los slots
    const BarberDisponibilidad = require('../models/barberDisponibilidad');
    const disp     = await BarberDisponibilidad.findOne({ barberId });
    const slotBase = disp?.duracionSlotMin ?? 30;

    let duracionTotal = slotBase;
    if (disp?.duracionPorServicio?.length > 0 && Array.isArray(servicios)) {
      let suma = 0;
      for (const svc of servicios) {
        const found = disp.duracionPorServicio.find(
          d => d.nombre.toLowerCase() === svc.toLowerCase());
        if (found) suma += found.duracionMin;
      }
      if (suma > 0) duracionTotal = suma;
    }

    const horaAMinutos = (h) => { const [hh, mm] = h.split(':').map(Number); return hh * 60 + mm; };
    const minutosAHora = (m) => `${Math.floor(m/60).toString().padStart(2,'0')}:${(m%60).toString().padStart(2,'0')}`;

    const horaInicioMin = horaAMinutos(hora);
    for (let min = horaInicioMin; min < horaInicioMin + duracionTotal; min += slotBase) {
      await AgendaSlot.findOneAndUpdate(
        { barberId, fecha, hora: minutosAHora(min) },
        { $set: { status: 'ocupado', clientId: userId, appointmentId: reservaGuardada._id } },
        { upsert: true }
      );
    }

    res.status(201).json({
      message:       'Cita creada, esperando confirmación del barbero',
      appointmentId: reservaGuardada._id,
      data:          reservaGuardada
    });
  } catch (error) {
    console.error('Error crear reserva:', error);
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