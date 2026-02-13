const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcryptjs');

// Registro de usuario
router.post('/register/user', async (req, res) => {
  try {
    console.log('Datos recibidos:', req.body); // Para debug
    
    const { nombre, correo, telefono, password } = req.body;
    
    // Validar campos requeridos
    if (!nombre || !correo || !telefono || !password) {
      return res.status(400).json({ 
        message: 'Todos los campos son requeridos' 
      });
    }
    
    // Verificar si el usuario ya existe
    const usuarioExistente = await User.findOne({ correo });
    if (usuarioExistente) {
      return res.status(400).json({ 
        message: 'El correo ya está registrado' 
      });
    }
    
    // Crear nuevo usuario (el middleware encriptará la contraseña automáticamente)
    const nuevoUsuario = new User({
      nombre,
      correo,
      telefono,
      password
    });
    
    // Guardar en la base de datos
    await nuevoUsuario.save();
    
    // No enviar la contraseña en la respuesta
    const usuarioResponse = nuevoUsuario.toObject();
    delete usuarioResponse.password;
    
    res.status(201).json({
      message: 'Usuario registrado exitosamente',
      user: usuarioResponse
    });
    
  } catch (error) {
    console.error('Error en registro:', error);
    res.status(500).json({ 
      message: 'Error en el servidor',
      error: error.message 
    });
  }
});

module.exports = router;