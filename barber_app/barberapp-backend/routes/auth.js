// routes/auth.js - VERSIÓN CORREGIDA
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcryptjs');

// ✅ REGISTRO DE USUARIO
router.post('/register/user', async (req, res) => {
  try {
    console.log('📝 Intento de registro: ', req.body);

    const { nombre, correo, telefono, password } = req.body;

    // Validar campos requeridos
    if (!nombre || !correo || !telefono || !password) {
      return res.status(400).json({
        message: 'Todos los campos son requeridos',
        required: ['nombre', 'correo', 'telefono', 'password']
      });
    }

    // Validar formato de email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(correo)) {
      return res.status(400).json({
        message: 'El formato del correo no es válido'
      });
    }

    // Validar longitud de contraseña
    if (password.length < 6) {
      return res.status(400).json({
        message: 'La contraseña debe tener al menos 6 caracteres'
      });
    }

    // Verificar si el usuario ya existe
    const usuarioExistente = await User.findOne({
      $or: [
        { correo: correo.toLowerCase() },
        { telefono: telefono }
      ]
    });

    if (usuarioExistente) {
      console.log('⚠️ El usuario ya existe:', correo);

      if (usuarioExistente.correo === correo.toLowerCase()) {
        return res.status(409).json({ // 409 Conflict es más apropiado que 400
          message: 'Este correo ya está registrado'
        });
      }

      if (usuarioExistente.telefono === telefono) {
        return res.status(409).json({
          message: 'Este número ya está registrado'
        });
      }
    }

    // Crear nuevo usuario
    const nuevoUsuario = new User({
      nombre,
      correo: correo.toLowerCase(),
      telefono,
      password,
      profileImage: null,
      isActive: true
    });

    // Guardar en base de datos
    await nuevoUsuario.save();

    console.log('✅ Usuario registrado exitosamente: ', nuevoUsuario.correo);

    // Preparar respuesta sin contraseña
    const usuarioResponse = nuevoUsuario.toObject();
    delete usuarioResponse.password;

    res.status(201).json({
      message: 'Usuario registrado exitosamente',
      user: usuarioResponse
    });

  } catch (error) {
    console.error('❌ Error en registro: ', error);

    // Error de clave duplicada (MongoDB)
    if (error.code === 11000) {
      const campoDuplicado = Object.keys(error.keyPattern)[0];
      return res.status(409).json({
        message: `El ${campoDuplicado === 'correo' ? 'correo' : 'teléfono'} ya está registrado`,
        field: campoDuplicado
      });
    }

    // Error de validación de Mongoose
    if (error.name === 'ValidationError') {
      const errors = Object.values(error.errors).map(e => e.message);
      return res.status(400).json({
        message: 'Error de validación',
        errors: errors
      });
    }

    res.status(500).json({
      message: 'Error en el servidor al registrar usuario',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// 🔐 LOGIN DE USUARIO - UNA SOLA VEZ, CORREGIDO
router.post('/login/user', async (req, res) => {
  try {
    console.log('🔑 Intento de login:', req.body);

    const { correo, password } = req.body;

    // Validar campos requeridos
    if (!correo || !password) {
      return res.status(400).json({
        message: 'Correo y contraseña son requeridos'
      });
    }

    // Buscar usuario por correo (case insensitive)
    const usuario = await User.findOne({ 
      correo: correo.toLowerCase() 
    });

    // Verificar si el usuario existe
    if (!usuario) {
      console.log('❌ Usuario no encontrado:', correo);
      return res.status(401).json({
        message: 'Credenciales inválidas'
      });
    }

    // Verificar si la cuenta está activa
    if (!usuario.isActive) {
      console.log('🚫 Cuenta inactiva:', correo);
      return res.status(403).json({
        message: 'La cuenta está desactivada. Contacta al soporte.'
      });
    }

    // Comparar contraseñas usando el método del modelo (CORREGIDO)
    const passwordValida = await usuario.comparePassword(password);

    if (!passwordValida) {
      console.log('❌ Contraseña incorrecta para:', correo);
      return res.status(401).json({
        message: 'Credenciales inválidas'
      });
    }

    console.log('✅ Login exitoso para:', correo);

    // No enviar la contraseña en la respuesta
    const usuarioResponse = usuario.toObject();
    delete usuarioResponse.password;

    res.json({
      message: 'Login exitoso',
      user: usuarioResponse
    });

  } catch (error) {
    console.error('❌ Error en login:', error);
    res.status(500).json({
      message: 'Error en el servidor',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;