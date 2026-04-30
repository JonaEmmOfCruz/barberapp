const express = require('express');
const router  = express.Router();
const Barbero = require('../models/userBarbero');
const AgendaSlot   = require('../models/barberAgendaSlot');
const BarberJornada = require('../models/barberJornada');

// GET /api/barbers — todos los barberos
router.get('/', async (req, res) => {
  try {
    const barbers = await Barbero.find();
    res.status(200).json(barbers);
  } catch (error) {
    res.status(500).json({ message: 'Error interno del servidor' });
  }
});

// GET /api/barbers/favorites/:userId — favoritos del usuario
router.get('/favorites/:userId', async (req, res) => {
  try {
    const favoritos = await Barbero.find({ favoritedBy: req.params.userId });
    res.status(200).json(favoritos);
  } catch (error) {
    res.status(500).json([]);
  }
});

// POST /api/barbers/favorite — agregar favorito
router.post('/favorite', async (req, res) => {
  const { barberId, userId } = req.body;
  try {
    await Barbero.findByIdAndUpdate(barberId, { $addToSet: { favoritedBy: userId } });
    res.status(200).json({ message: 'Añadido a favoritos' });
  } catch (error) {
    res.status(500).json({ message: 'Error al añadir a favoritos' });
  }
});

// DELETE /api/barbers/favorite — quitar favorito
router.delete('/favorite', async (req, res) => {
  const { barberId, userId } = req.body;
  try {
    await Barbero.findByIdAndUpdate(barberId, { $pull: { favoritedBy: userId } });
    res.status(200).json({ message: 'Quitado de favoritos' });
  } catch (error) {
    res.status(500).json({ message: 'Error al quitar de favoritos' });
  }
});

// GET /api/barbers/disponibles — barberos con jornada abierta
router.get('/disponibles', async (req, res) => {
  try {
    const ahora = new Date();
    ahora.setHours(ahora.getHours() - 6);
    const hoy = ahora.toISOString().split('T')[0];
    const db  = require('mongoose').connection.db;

    const jornadas = await BarberJornada.find({
      fecha:  { $gte: hoy },
      status: 'abierta'
    });

    const resultado = await Promise.all(
      jornadas.map(async (j) => {
        const barbero = await db.collection('barberos').findOne(
          { _id: j.barberId },
          { projection: { nombre: 1, ciudad: 1 } }
        );
       const docs = await db.collection('barberDocuments').findOne(
  { barberId: j.barberId.toString() },
  { projection: { profileImage: 1 } }

        );
        const slots = await AgendaSlot.find({
          barberId: j.barberId,
          fecha:    j.fecha,
          status:   'disponible'
        }).sort({ horaMinutos: 1 });

        return {
          barberId:     j.barberId,
          nombre:       barbero?.nombre ?? 'Barbero',
          profileImage: docs?.profileImage ?? null,
          ciudad:       barbero?.ciudad ?? '',
          fecha:        j.fecha,
          inicioHora:   j.inicioHora,
          finHora:      j.finHora,
          slots:        slots.map(s => ({ hora: s.hora, horaMinutos: s.horaMinutos }))
        };
      })
    );

    const conSlots = resultado.filter(b => b.slots.length > 0);
    res.status(200).json(conSlots);

  } catch (error) {
    console.error('Error barberos disponibles:', error);
    res.status(500).json({ message: 'Error del servidor' });
  }
});

router.get('/:barberId/slots', async (req, res) => {
  try {
    const { barberId } = req.params;
    
    // Usar fecha con offset de Guadalajara si no viene en el query
    let fecha = req.query.fecha;
    if (!fecha) {
      const ahora = new Date();
      ahora.setHours(ahora.getHours() - 6); // UTC-6
      fecha = ahora.toISOString().split('T')[0];
    }

    const slots = await AgendaSlot.find({
      barberId,
      fecha,
      status: 'disponible'
    }).sort({ horaMinutos: 1 });

    res.status(200).json({
      fecha,
      slots: slots.map(s => ({ hora: s.hora, horaMinutos: s.horaMinutos }))
    });
  } catch (error) {
    res.status(500).json({ message: 'Error del servidor' });
  }
});

module.exports = router;