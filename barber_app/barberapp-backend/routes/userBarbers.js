const express = require('express');
const router  = express.Router();
const mongoose = require('mongoose');

const AgendaSlot   = require('../models/barberAgendaSlot');
const Barbero     = require('../models/barberos');

// GET /api/barbers — todos los barberos
router.get('/', async (req, res) => {
  try {
    const barbers = await Barbero.find();
    res.status(200).json(barbers);
  } catch (error) {
    res.status(500).json({ message: 'Error interno del servidor' });
  }
});

router.get('/favorites/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const db = require('mongoose').connection.db;

    const favoritos = await Barbero.find({ favoritedBy: userId });

    const resultado = await Promise.all(favoritos.map(async (b) => {
      const docs = await db.collection('barberDocuments').findOne(
        { barberId: b._id.toString() },
        { projection: { profileImage: 1 } }
      );
      return {
        ...b.toObject(),
        profileImage: docs?.profileImage ?? null,
      };
    }));

    res.status(200).json(resultado);
  } catch (error) {
    console.error("ERROR EN GET FAVORITOS:", error);
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

// GET /api/barbers/disponibles — barberos con horario configurado
router.get('/disponibles', async (req, res) => {
  try {
    const mongoose = require('mongoose');
    const db = mongoose.connection.db;
    const BarberDisponibilidad = require('../models/barberDisponibilidad');

    // Obtener todos los barberos con horario configurado
    const disponibilidades = await BarberDisponibilidad.find({
      diasDisponibles: { $exists: true, $not: { $size: 0 } }
    });

    const resultado = await Promise.all(
      disponibilidades.map(async (disp) => {
        const barbero = await db.collection('barberos').findOne(
          { _id: disp.barberId },
          { projection: { nombre: 1, ciudad: 1, estado: 1, calificacion: 1 } }
        );

        const docs = await db.collection('barberDocuments').findOne(
          { barberId: disp.barberId.toString() },
          { projection: { profileImage: 1 } }
        );

        return {
          _id:             disp.barberId,
          barberId:        disp.barberId,
          nombre:          barbero.nombre ?? 'Barbero',
          profileImage:    docs?.profileImage ?? null,
          ciudad:          barbero.ciudad ?? '',
          diasDisponibles: disp.diasDisponibles,
          diasBloqueados:  disp.diasBloqueados ?? [],
          calificacion:    barbero.calificacion ?? { promedio: 0, totalReseñas: 0 },

        };
      })
    );

    const filtrado = resultado.filter(b => b !== null);
    res.status(200).json(filtrado);

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

router.get('/:barberId/servicios', async (req, res) => {
  try {
    const mongoose = require('mongoose');
    const db = mongoose.connection.db;
    const barbero = await db.collection('barberos').findOne(
      { _id: new mongoose.Types.ObjectId(req.params.barberId) },
      { projection: { servicios: 1 } }
    );
    res.json({ servicios: barbero?.servicios ?? [] });
  } catch (error) {
    console.error('Error servicios:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

router.post('/:barberId/calificar', async (req, res) => {
  try {
    const { estrellas, userId, reservaId } = req.body;

    if (!estrellas || estrellas < 1 || estrellas > 5) {
      return res.status(400).json({ error: 'Calificación inválida' });
    }

    const mongoose = require('mongoose');
    const db = mongoose.connection.db;

    // ── Buscar en userReservas (citas agendadas) ──────────────
    let reserva = await db.collection('userReservas').findOne({
      _id:      new mongoose.Types.ObjectId(reservaId),
      userId:   new mongoose.Types.ObjectId(userId),
      barberId: new mongoose.Types.ObjectId(req.params.barberId),
      status:   'completada',
    });

    let coleccion = 'userReservas';

    // ── Si no está ahí, buscar en servicerequests (runner) ────
    if (!reserva) {
      const ServiceRequest = require('../models/userServiceRequest');
      reserva = await ServiceRequest.findOne({
        _id:       new mongoose.Types.ObjectId(reservaId),
        userId:    new mongoose.Types.ObjectId(userId),
        barberoId: req.params.barberId,
        estado:    'finalizado',
      });
      coleccion = 'servicerequests';
    }

    console.log('reserva encontrada:', reserva ? 'SÍ' : 'NO');
console.log('reservaId recibido:', reservaId);
console.log('userId recibido:', userId);
console.log('barberId recibido:', req.params.barberId);

    if (!reserva) {
      return res.status(400).json({ error: 'No puedes calificar esta cita' });
    }
    
console.log('coleccion:', coleccion);
console.log('calificado?:', reserva.calificado);
    if (reserva.calificado) {
      return res.status(400).json({ error: 'Ya calificaste esta cita' });
    }
console.log('buscando barbero...');
    // ── Actualizar promedio del barbero ───────────────────────
    const Barber = require('../models/barberos');
    const barbero = await Barber.findById(req.params.barberId);
    console.log('barbero encontrado:', barbero ? barbero.nombre : 'NO ENCONTRADO');
    if (!barbero) return res.status(404).json({ error: 'Barbero no encontrado' });

    const totalActual    = barbero.calificacion?.totalReseñas ?? 0;
    const promedioActual = barbero.calificacion?.promedio ?? 0;
    const nuevoTotal     = totalActual + 1;
    const nuevoPromedio  = ((promedioActual * totalActual) + estrellas) / nuevoTotal;
    console.log('calculando promedio:', { totalActual, promedioActual, nuevoTotal, nuevoPromedio });

    await Barber.findByIdAndUpdate(req.params.barberId, {
      'calificacion.promedio':     Math.round(nuevoPromedio * 10) / 10,
      'calificacion.totalReseñas': nuevoTotal,
    });

    console.log('barbero actualizado ✅');

    // ── Marcar como calificado en la colección correcta ───────
    if (coleccion === 'userReservas') {
      await db.collection('userReservas').updateOne(
        { _id: new mongoose.Types.ObjectId(reservaId) },
        { $set: { calificado: true } }
      );
    } else {
      const ServiceRequest = require('../models/userServiceRequest');
      await ServiceRequest.findByIdAndUpdate(reservaId, { calificado: true });
    }

    res.json({ success: true, nuevoPromedio: Math.round(nuevoPromedio * 10) / 10 });

 } catch (error) {
    console.error('Error completo:', error.message);
    console.error('Stack:', error.stack);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// GET /api/barbers/:barberId/zona-trabajo
router.get('/:barberId/zona-trabajo', async (req, res) => {
  try {
    const Barber  = require('../models/barberos');
    const barbero = await Barber.findById(req.params.barberId, { zonasTrabajo: 1 });
    res.json(barbero?.zonasTrabajo ?? { radioKm: 10, zonasFavoritas: [] });
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// PUT /api/barbers/:barberId/zona-trabajo
router.put('/:barberId/zona-trabajo', async (req, res) => {
  try {
    const { radioKm, zonasFavoritas } = req.body;
    const Barber = require('../models/barberos');
    await Barber.findByIdAndUpdate(req.params.barberId, {
      'zonasTrabajo.radioKm':        radioKm        ?? 10,
      'zonasTrabajo.zonasFavoritas': zonasFavoritas ?? [],
    });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

module.exports = router;