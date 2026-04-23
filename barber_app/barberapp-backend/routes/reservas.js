const express = require('express');
const router = express.Router();
const Appointment = require('../models/reservas'); // Asegúrate de que la ruta al modelo sea correcta

router.post('/create', async (req, res) => {
  console.log("Datos recibidos para reserva:", req.body);
  
  try {
    const { userId, barberId, fecha, hora } = req.body;

    // 1. Validación de datos obligatorios (igual que en serviceRequests)
    if (!userId || !barberId || !fecha || !hora) {
      return res.status(400).json({ 
        error: 'Faltan datos obligatorios para la reserva' 
      });
    }

    // 2. Crear la nueva cita con los datos recibidos
    const newAppointment = new Appointment({
      userId,
      barberId,
      fecha,
      hora,
      status: 'pendiente' // Estado inicial por defecto
    });

    // 3. Guardar en la base de datos
    const savedAppointment = await newAppointment.save();

    // 4. Respuesta exitosa estructurada
    res.status(201).json({
      message: "Cita creada con éxito",
      appointmentId: savedAppointment._id,
      data: savedAppointment
    });

  } catch (error) {
    console.error("Error en DB Reservas:", error.message);
    
    // Manejo de errores de validación de Mongoose o CastError (IDs mal formados)
    if (error.name === 'ValidationError' || error.name === 'CastError') {
      return res.status(400).json({ error: "Datos o IDs inválidos: " + error.message });
    }

    res.status(500).json({ error: 'Error interno del servidor al crear la reserva' });
  }
});

// Opcional: Obtener una reserva por ID (similar a serviceRequests)
router.get('/:id', async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id)
      .populate('barberId', 'nombre') // Si quieres traer datos del barbero
      .populate('userId', 'nombre email'); // Si quieres traer datos del usuario
      
    if (!appointment) {
      return res.status(404).json({ error: 'Reserva no encontrada' });
    }
    res.json(appointment);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error del servidor al obtener la reserva' });
  }
});

module.exports = router;