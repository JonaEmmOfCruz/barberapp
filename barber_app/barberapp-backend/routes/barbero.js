const express = require('express');
const router = express.Router();
const Barbero = require('../models/Barbero');

// Registro de barbero
router.post('/register/barbero', async (req, res) => {
  try {
    console.log('Datos recibidos:', req.body);

    const { nombre, correo, telefono, password, experiencia, vehiculo } = req.body;

    // Validar campos requeridos
    if (!nombre || !correo || !telefono || !password) {
      return res.status(400).json({ 
        message: 'Todos los campos personales son requeridos' 
      });
    }

    // Verificar si el barbero ya existe
    const barberoExistente = await Barbero.findOne({ correo });
    if (barberoExistente) {
      return res.status(400).json({ 
        message: 'El correo ya está registrado' 
      });
    }

    // Crear nuevo barbero (la contraseña se encripta automáticamente en el modelo)
    const nuevoBarbero = new Barbero({
      nombre,
      correo,
      telefono,
      password,
      experiencia,
      vehiculo
    });

    await nuevoBarbero.save();

    // No enviar la contraseña en la respuesta
    const barberoResponse = nuevoBarbero.toObject();
    delete barberoResponse.password;

    res.status(201).json({
      message: 'Barbero registrado exitosamente',
      barbero: barberoResponse
    });

  } catch (error) {
    console.error('Error en registro de barbero:', error);
    res.status(500).json({ 
      message: 'Error en el servidor',
      error: error.message 
    });
  }
});

module.exports = router;