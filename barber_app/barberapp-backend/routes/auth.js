// routes/auth.js - VERSIÓN CORREGIDA
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');

// ✅ REGISTRO DE USUARIO NORMAL
router.post('/register/user', async (req, res) => {
  try {
    console.log('📝 Intento de registro de usuario: ', req.body);

    const { nombre, correo, telefono, password } = req.body;

    if (!nombre || !correo || !telefono || !password) {
      return res.status(400).json({
        message: 'Todos los campos son requeridos',
        required: ['nombre', 'correo', 'telefono', 'password']
      });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(correo)) {
      return res.status(400).json({
        message: 'El formato del correo no es válido'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        message: 'La contraseña debe tener al menos 6 caracteres'
      });
    }

    const usuarioExistente = await User.findOne({
      $or: [
        { correo: correo.toLowerCase() },
        { telefono: telefono }
      ]
    });

    if (usuarioExistente) {
      if (usuarioExistente.correo === correo.toLowerCase()) {
        return res.status(409).json({
          message: 'Este correo ya está registrado'
        });
      }
      if (usuarioExistente.telefono === telefono) {
        return res.status(409).json({
          message: 'Este número ya está registrado'
        });
      }
    }

    const nuevoUsuario = new User({
      nombre,
      correo: correo.toLowerCase(),
      telefono,
      password,
      profileImage: null,
      isActive: true
    });

    await nuevoUsuario.save();

    console.log('✅ Usuario registrado exitosamente: ', nuevoUsuario.correo);

    const usuarioResponse = nuevoUsuario.toObject();
    delete usuarioResponse.password;

    res.status(201).json({
      success: true,
      message: 'Usuario registrado exitosamente',
      user: usuarioResponse,
      userId: nuevoUsuario._id
    });

  } catch (error) {
    console.error('❌ Error en registro de usuario: ', error);

    if (error.code === 11000) {
      const campoDuplicado = Object.keys(error.keyPattern)[0];
      return res.status(409).json({
        success: false,
        message: `El ${campoDuplicado === 'correo' ? 'correo' : 'teléfono'} ya está registrado`,
        field: campoDuplicado
      });
    }

    if (error.name === 'ValidationError') {
      const errors = Object.values(error.errors).map(e => e.message);
      return res.status(400).json({
        success: false,
        message: 'Error de validación',
        errors: errors
      });
    }

    res.status(500).json({
      success: false,
      message: 'Error en el servidor al registrar usuario',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// 🔐 LOGIN UNIFICADO - VERIFICA EN USERS Y BARBEROS
router.post('/login', async (req, res) => {
  try {
    console.log('🔑 Intento de login:', req.body);

    const { email, password, isBarber } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email y contraseña son requeridos'
      });
    }

    // Verificar que la conexión de MongoDB esté activa
    if (!mongoose.connection || !mongoose.connection.db) {
      console.error('❌ No hay conexión activa con MongoDB');
      return res.status(500).json({
        success: false,
        message: 'Error de conexión con la base de datos'
      });
    }

    // LOGIN COMO BARBERO
    if (isBarber) {
      console.log('🔍 Buscando barbero en MongoDB...');
      
      // Usar la conexión de Mongoose
      const db = mongoose.connection.db;
      const collection = db.collection("barberos");
      
      // Buscar barbero por EMAIL (el campo en la colección es 'email', no 'correo')
      const barbero = await collection.findOne({ email: email.toLowerCase() });
      
      console.log('📄 Barbero encontrado:', barbero ? 'Sí' : 'No');
      if (barbero) {
        console.log('   - ID:', barbero._id);
        console.log('   - Nombre:', barbero.nombre);
        console.log('   - Email:', barbero.email);
        console.log('   - Estado:', barbero.estado);
        console.log('   - Contraseña almacenada:', barbero.password);
      }
      
      if (!barbero) {
        console.log('❌ Barbero no encontrado con email:', email);
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas'
        });
      }

      // Verificar si el barbero está activo (usando el campo 'estado')
      if (barbero.estado !== 'activo') {
        console.log('🚫 Barbero inactivo:', email);
        return res.status(403).json({
          success: false,
          message: 'Tu cuenta de barbero está inactiva. Contacta al administrador.'
        });
      }

      // IMPORTANTE: La contraseña del barbero NO está hasheada, está en texto plano
      // Por lo tanto, comparamos directamente
      console.log('🔐 Comparando contraseña (texto plano)...');
      console.log('   Contraseña ingresada:', password);
      console.log('   Contraseña almacenada:', barbero.password);
      const passwordValida = (password === barbero.password);
      console.log('   Resultado:', passwordValida ? '✅ Válida' : '❌ Inválida');
      
      if (!passwordValida) {
        console.log('❌ Contraseña incorrecta para barbero:', email);
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas'
        });
      }

      console.log('✅ Login exitoso como barbero:', email);

      return res.json({
        success: true,
        message: 'Login exitoso como barbero',
        userId: barbero._id,
        user: {
          userId: barbero._id,
          nombre: barbero.nombre,
          email: barbero.email,
          role: 'barber',
          barberId: barbero.barberId,
          profileImage: null,
          estado: barbero.estado
        }
      });
    }

    // LOGIN COMO USUARIO NORMAL
    console.log('🔍 Buscando usuario en MongoDB...');
    
    const usuario = await User.findOne({ 
      correo: email.toLowerCase() 
    });

    if (!usuario) {
      console.log('❌ Usuario no encontrado:', email);
      return res.status(401).json({
        success: false,
        message: 'Credenciales inválidas'
      });
    }

    if (!usuario.isActive) {
      console.log('🚫 Cuenta inactiva:', email);
      return res.status(403).json({
        success: false,
        message: 'La cuenta está desactivada. Contacta al soporte.'
      });
    }

    const passwordValida = await usuario.comparePassword(password);

    if (!passwordValida) {
      console.log('❌ Contraseña incorrecta para:', email);
      return res.status(401).json({
        success: false,
        message: 'Credenciales inválidas'
      });
    }

    console.log('✅ Login exitoso como usuario:', email);

    const usuarioResponse = usuario.toObject();
    delete usuarioResponse.password;

    res.json({
      success: true,
      message: 'Login exitoso',
      userId: usuario._id,
      user: {
        userId: usuario._id,
        nombre: usuario.nombre,
        email: usuario.correo,
        telefono: usuario.telefono,
        role: 'user',
        profileImage: usuario.profileImage || null,
        isActive: usuario.isActive
      }
    });

  } catch (error) {
    console.error('❌ Error en login:', error);
    res.status(500).json({
      success: false,
      message: 'Error en el servidor',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Obtener perfil de barbero por ID
router.get('/barber/:barberId', async (req, res) => {
  try {
    const { barberId } = req.params;
    
    if (!mongoose.connection || !mongoose.connection.db) {
      return res.status(500).json({
        success: false,
        message: 'Error de conexión con la base de datos'
      });
    }
    
    const db = mongoose.connection.db;
    const collection = db.collection("barberos");
    
    const { ObjectId } = require('mongodb');
    let barbero;
    
    try {
      barbero = await collection.findOne({ _id: new ObjectId(barberId) });
    } catch (e) {
      barbero = await collection.findOne({ barberId: barberId });
    }
    
    if (!barbero) {
      return res.status(404).json({
        success: false,
        message: 'Barbero no encontrado'
      });
    }

    const { password, ...barberoData } = barbero;

    res.status(200).json({
      success: true,
      barber: barberoData
    });

  } catch (error) {
    console.error('Error obteniendo perfil de barbero:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

module.exports = router;