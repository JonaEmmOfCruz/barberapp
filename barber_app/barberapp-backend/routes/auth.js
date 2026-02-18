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

// 🔐 LOGIN DE USUARIO - Ruta que te falta
router.post('/login/user', async (req, res) => {
  try {
    console.log('Intento de login:', req.body);
    
    const { correo, password } = req.body;
    
    // Validar campos requeridos
    if (!correo || !password) {
      return res.status(400).json({ 
        message: 'Correo y contraseña son requeridos' 
      });
    }
    
    // Buscar usuario por correo
    const usuario = await User.findOne({ correo });
    
    // Verificar si el usuario existe
    if (!usuario) {
      console.log('Usuario no encontrado:', correo);
      return res.status(401).json({ 
        message: 'Credenciales inválidas' 
      });
    }
    
    // Comparar contraseñas usando bcrypt
    const passwordValida = await bcrypt.compare(password, usuario.password);
    
    if (!passwordValida) {
      console.log('Contraseña incorrecta para:', correo);
      return res.status(401).json({ 
        message: 'Credenciales inválidas' 
      });
    }
    
    console.log('Login exitoso para:', correo);
    
    // No enviar la contraseña en la respuesta
    const usuarioResponse = usuario.toObject();
    delete usuarioResponse.password;
    
    res.json({
      message: 'Login exitoso',
      user: usuarioResponse
    });
    
  } catch (error) {
    console.error('Error en login:', error);
    res.status(500).json({ 
      message: 'Error en el servidor',
      error: error.message 
    });
  }
});

module.exports = router;