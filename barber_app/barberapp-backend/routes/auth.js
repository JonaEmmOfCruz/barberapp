// routes/auth.js - VERSIÓN CORREGIDA CON SOPORTE PARA IDENTIFIER
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { ObjectId } = require('mongodb');

// ✅ REGISTRO DE USUARIO NORMAL (sin cambios)
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

// 🔐 LOGIN UNIFICADO - VERIFICA EN USERS Y BARBEROS (VERSIÓN MEJORADA)
router.post('/login', async (req, res) => {
  try {
    console.log('🔑 Intento de login:', req.body);

    // Aceptar tanto 'identifier' como 'email' para compatibilidad
    const { identifier, email, password, isBarber } = req.body;
    
    // Usar identifier si existe, si no usar email
    const loginIdentifier = identifier || email;

    if (!loginIdentifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Identificador (email o nombre de usuario) y contraseña son requeridos'
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
      console.log('🔍 Buscando barbero en MongoDB con:', loginIdentifier);
      
      const db = mongoose.connection.db;
      const collection = db.collection("barberos");
      
      // Buscar barbero por EMAIL o por NOMBRE
      const barbero = await collection.findOne({
        $or: [
          { email: loginIdentifier.toLowerCase() },
          { nombre: loginIdentifier }
        ]
      });
      
      console.log('📄 Barbero encontrado:', barbero ? 'Sí' : 'No');
      if (barbero) {
        console.log('   - ID:', barbero._id);
        console.log('   - Nombre:', barbero.nombre);
        console.log('   - Email:', barbero.email);
        console.log('   - Estado:', barbero.estado);
      }
      
      if (!barbero) {
        console.log('❌ Barbero no encontrado con identifier:', loginIdentifier);
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas. Verifica tu nombre de usuario o correo.'
        });
      }

      // Verificar si el barbero está activo
      if (barbero.estado !== 'activo') {
        console.log('🚫 Barbero inactivo:', loginIdentifier);
        return res.status(403).json({
          success: false,
          message: 'Tu cuenta de barbero está inactiva. Contacta al administrador.'
        });
      }

      // Comparar contraseña (texto plano)
      console.log('🔐 Comparando contraseña...');
      const passwordValida = (password === barbero.password);
      console.log('   Resultado:', passwordValida ? '✅ Válida' : '❌ Inválida');
      
      if (!passwordValida) {
        console.log('❌ Contraseña incorrecta para barbero:', loginIdentifier);
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas. Contraseña incorrecta.'
        });
      }

      console.log('✅ Login exitoso como barbero:', barbero.nombre);

      return res.json({
        success: true,
        message: `Bienvenido ${barbero.nombre}`,
        userId: barbero._id,
        isBarber: true,
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
    console.log('🔍 Buscando usuario en MongoDB con:', loginIdentifier);
    
    // Buscar usuario por CORREO o por NOMBRE
    const usuario = await User.findOne({
      $or: [
        { correo: loginIdentifier.toLowerCase() },
        { nombre: loginIdentifier }
      ]
    });

    if (!usuario) {
      console.log('❌ Usuario no encontrado:', loginIdentifier);
      return res.status(401).json({
        success: false,
        message: 'Credenciales inválidas. Verifica tu nombre de usuario o correo.'
      });
    }

    console.log('📄 Usuario encontrado:', usuario.nombre);
    console.log('   - ID:', usuario._id);
    console.log('   - Correo:', usuario.correo);
    console.log('   - Activo:', usuario.isActive);

    if (!usuario.isActive) {
      console.log('🚫 Cuenta inactiva:', loginIdentifier);
      return res.status(403).json({
        success: false,
        message: 'La cuenta está desactivada. Contacta al soporte.'
      });
    }

    const passwordValida = await usuario.comparePassword(password);

    if (!passwordValida) {
      console.log('❌ Contraseña incorrecta para:', loginIdentifier);
      return res.status(401).json({
        success: false,
        message: 'Credenciales inválidas. Contraseña incorrecta.'
      });
    }

    console.log('✅ Login exitoso como usuario:', usuario.nombre);

    const usuarioResponse = usuario.toObject();
    delete usuarioResponse.password;

    res.json({
      success: true,
      message: `Bienvenido ${usuario.nombre}`,
      userId: usuario._id,
      isBarber: false,
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

// NUEVO ENDPOINT: LOGIN UNIFICADO SIN ISBARBER (DETECCIÓN AUTOMÁTICA)
router.post('/login/unified', async (req, res) => {
  try {
    console.log('🔑 Intento de login unificado (detección automática):', req.body);

    const { identifier, password } = req.body;

    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Identificador y contraseña son requeridos'
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

    // 1. PRIMERO BUSCAR EN BARBEROS
    console.log('🔍 Buscando en barberos...');
    const db = mongoose.connection.db;
    const barberosCollection = db.collection("barberos");
    
    const barbero = await barberosCollection.findOne({
      $or: [
        { email: identifier.toLowerCase() },
        { nombre: identifier }
      ]
    });
    
    if (barbero) {
      console.log('📄 Barbero encontrado:', barbero.nombre);
      
      // Verificar estado del barbero
      if (barbero.estado !== 'activo') {
        console.log('🚫 Barbero inactivo');
        return res.status(403).json({
          success: false,
          message: 'Tu cuenta de barbero está inactiva. Contacta al administrador.'
        });
      }
      
      // Verificar contraseña
      const passwordValida = (password === barbero.password);
      
      if (!passwordValida) {
        console.log('❌ Contraseña incorrecta para barbero');
        return res.status(401).json({
          success: false,
          message: 'Contraseña incorrecta'
        });
      }
      
      console.log('✅ Login exitoso como barbero:', barbero.nombre);
      
      return res.json({
        success: true,
        message: `Bienvenido ${barbero.nombre}`,
        userId: barbero._id,
        isBarber: true,
        user: {
          userId: barbero._id,
          nombre: barbero.nombre,
          email: barbero.email,
          role: 'barber',
          barberId: barbero.barberId,
          estado: barbero.estado
        }
      });
    }
    
    // 2. SI NO ES BARBERO, BUSCAR EN USUARIOS
    console.log('🔍 Buscando en usuarios...');
    const usuario = await User.findOne({
      $or: [
        { correo: identifier.toLowerCase() },
        { nombre: identifier }
      ]
    });
    
    if (usuario) {
      console.log('📄 Usuario encontrado:', usuario.nombre);
      
      if (!usuario.isActive) {
        console.log('🚫 Cuenta inactiva');
        return res.status(403).json({
          success: false,
          message: 'La cuenta está desactivada. Contacta al soporte.'
        });
      }
      
      const passwordValida = await usuario.comparePassword(password);
      
      if (!passwordValida) {
        console.log('❌ Contraseña incorrecta para usuario');
        return res.status(401).json({
          success: false,
          message: 'Contraseña incorrecta'
        });
      }
      
      console.log('✅ Login exitoso como usuario:', usuario.nombre);
      
      const usuarioResponse = usuario.toObject();
      delete usuarioResponse.password;
      
      return res.json({
        success: true,
        message: `Bienvenido ${usuario.nombre}`,
        userId: usuario._id,
        isBarber: false,
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
    }
    
    // 3. NO SE ENCONTRÓ EN NINGUNA COLECCIÓN
    console.log('❌ Usuario no encontrado en ninguna colección:', identifier);
    return res.status(401).json({
      success: false,
      message: 'Usuario no encontrado. Verifica tu nombre de usuario o correo.'
    });
    
  } catch (error) {
    console.error('❌ Error en login unificado:', error);
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