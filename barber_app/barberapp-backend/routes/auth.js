const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { ObjectId } = require('mongodb');

// ─────────────────────────────────────────────
// HELPER: hashear contraseña
// ─────────────────────────────────────────────
const hashPassword = async (plain) => bcrypt.hash(plain, 10);
const comparePassword = async (plain, hashed) => bcrypt.compare(plain, hashed);

// ─────────────────────────────────────────────
// REGISTRO DE USUARIO NORMAL
// ─────────────────────────────────────────────
router.post('/register/user', async (req, res) => {
  try {
    console.log('📝 Intento de registro de usuario:', req.body);

    const { nombre, correo, telefono, password } = req.body;

    if (!nombre || !correo || !telefono || !password) {
      return res.status(400).json({
        message: 'Todos los campos son requeridos',
        required: ['nombre', 'correo', 'telefono', 'password']
      });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(correo)) {
      return res.status(400).json({ message: 'El formato del correo no es válido' });
    }

    if (password.length < 6) {
      return res.status(400).json({ message: 'La contraseña debe tener al menos 6 caracteres' });
    }

    const usuarioExistente = await User.findOne({
      $or: [
        { correo: correo.toLowerCase() },
        { telefono }
      ]
    });

    if (usuarioExistente) {
      if (usuarioExistente.correo === correo.toLowerCase()) {
        return res.status(409).json({ message: 'Este correo ya está registrado' });
      }
      if (usuarioExistente.telefono === telefono) {
        return res.status(409).json({ message: 'Este número ya está registrado' });
      }
    }

    const nuevoUsuario = new User({
      nombre,
      correo:       correo.toLowerCase(),
      telefono,
      password,
      profileImage: null,
      isActive:     true
    });

    await nuevoUsuario.save();
    console.log('✅ Usuario registrado:', nuevoUsuario.correo);

    const usuarioResponse = nuevoUsuario.toObject();
    delete usuarioResponse.password;

    return res.status(201).json({
      success: true,
      message: 'Usuario registrado exitosamente',
      user:    usuarioResponse,
      userId:  nuevoUsuario._id
    });

  } catch (error) {
    console.error('❌ Error en registro de usuario:', error);

    if (error.code === 11000) {
      const campo = Object.keys(error.keyPattern)[0];
      return res.status(409).json({
        success: false,
        message: `El ${campo === 'correo' ? 'correo' : 'teléfono'} ya está registrado`,
        field:   campo
      });
    }

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        success: false,
        message: 'Error de validación',
        errors:  Object.values(error.errors).map(e => e.message)
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Error en el servidor al registrar usuario',
      error:   process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// ─────────────────────────────────────────────
// LOGIN CON isBarber EXPLÍCITO
// ─────────────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    console.log('🔑 Intento de login:', req.body);

    const { identifier, email, password, isBarber } = req.body;
    const loginIdentifier = identifier || email;

    if (!loginIdentifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Identificador y contraseña son requeridos'
      });
    }

    if (!mongoose.connection?.db) {
      return res.status(500).json({ success: false, message: 'Error de conexión con la base de datos' });
    }

    // ── LOGIN BARBERO ──────────────────────────────────────────────
    if (isBarber) {
      const db       = mongoose.connection.db;
      const barberos = db.collection('barberos');

      const barbero = await barberos.findOne({
        $or: [
          { email:  loginIdentifier.toLowerCase() },
          { nombre: loginIdentifier }
        ]
      });

      if (!barbero) {
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas. Verifica tu nombre de usuario o correo.'
        });
      }

      // Comparar contraseña con bcrypt
      // NOTA: si el barbero aún tiene contraseña en texto plano en BD,
      // migra ejecutando: collection.updateOne({_id}, {$set:{password: await hashPassword(plain)}})
      const passwordValida = await comparePassword(password, barbero.password);

      if (!passwordValida) {
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas. Contraseña incorrecta.'
        });
      }

      console.log('✅ Login exitoso como barbero:', barbero.nombre);

      return res.json({
        success:  true,
        message:  `Bienvenido ${barbero.nombre}`,
        userId:   barbero._id,
        isBarber: true,
        user: {
          userId:       barbero._id,
          nombre:       barbero.nombre,
          email:        barbero.email,
          role:         'barber',
          barberId:     barbero.barberId,
          profileImage: barbero.profileImage || null,
          estado:       barbero.estado
        }
      });
    }

    // ── LOGIN USUARIO NORMAL ───────────────────────────────────────
    const usuario = await User.findOne({
      $or: [
        { correo: loginIdentifier.toLowerCase() },
        { nombre: loginIdentifier }
      ]
    });

    if (!usuario) {
      return res.status(401).json({
        success: false,
        message: 'Credenciales inválidas. Verifica tu nombre de usuario o correo.'
      });
    }

    const passwordValida = await usuario.comparePassword(password);

    if (!passwordValida) {
      return res.status(401).json({
        success: false,
        message: 'Credenciales inválidas. Contraseña incorrecta.'
      });
    }

    console.log('✅ Login exitoso como usuario:', usuario.nombre);

    const usuarioResponse = usuario.toObject();
    delete usuarioResponse.password;

    return res.json({
      success:  true,
      message:  `Bienvenido ${usuario.nombre}`,
      userId:   usuario._id,
      isBarber: false,
      user: {
        userId:       usuario._id,
        nombre:       usuario.nombre,
        email:        usuario.correo,
        telefono:     usuario.telefono,
        role:         'user',
        profileImage: usuario.profileImage || null,
        isActive:     usuario.isActive
      }
    });

  } catch (error) {
    console.error('❌ Error en login:', error);
    return res.status(500).json({
      success: false,
      message: 'Error en el servidor',
      error:   process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// ─────────────────────────────────────────────
// LOGIN UNIFICADO (detección automática)
// ─────────────────────────────────────────────
router.post('/login/unified', async (req, res) => {
  try {
    console.log('🔑 Login unificado:', req.body);

    const { identifier, password } = req.body;

    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Identificador y contraseña son requeridos'
      });
    }

    if (!mongoose.connection?.db) {
      return res.status(500).json({ success: false, message: 'Error de conexión con la base de datos' });
    }

    // 1. Buscar en barberos primero
    const db      = mongoose.connection.db;
    const barberos = db.collection('barberos');

    const barbero = await barberos.findOne({
      $or: [
        { email:  identifier.toLowerCase() },
        { nombre: identifier }
      ]
    });

    if (barbero) {
      const passwordValida = await comparePassword(password, barbero.password);

      if (!passwordValida) {
        return res.status(401).json({ success: false, message: 'Contraseña incorrecta' });
      }

      console.log('✅ Login exitoso como barbero:', barbero.nombre);

      return res.json({
        success:  true,
        message:  `Bienvenido ${barbero.nombre}`,
        userId:   barbero._id,
        isBarber: true,
        user: {
          userId:       barbero._id,
          nombre:       barbero.nombre,
          email:        barbero.email,
          role:         'barber',
          barberId:     barbero.barberId,
          profileImage: barbero.profileImage || null,
          estado:       barbero.estado
        }
      });
    }

    // 2. Buscar en usuarios normales
    const usuario = await User.findOne({
      $or: [
        { correo: identifier.toLowerCase() },
        { nombre: identifier }
      ]
    });

    if (usuario) {
      const passwordValida = await usuario.comparePassword(password);

      if (!passwordValida) {
        return res.status(401).json({ success: false, message: 'Contraseña incorrecta' });
      }

      console.log('✅ Login exitoso como usuario:', usuario.nombre);

      const usuarioResponse = usuario.toObject();
      delete usuarioResponse.password;

      return res.json({
        success:  true,
        message:  `Bienvenido ${usuario.nombre}`,
        userId:   usuario._id,
        isBarber: false,
        user: {
          userId:       usuario._id,
          nombre:       usuario.nombre,
          email:        usuario.correo,
          telefono:     usuario.telefono,
          role:         'user',
          profileImage: usuario.profileImage || null,
          isActive:     usuario.isActive
        }
      });
    }

    // 3. No encontrado en ninguna colección
    return res.status(401).json({
      success: false,
      message: 'Usuario no encontrado. Verifica tu nombre de usuario o correo.'
    });

  } catch (error) {
    console.error('❌ Error en login unificado:', error);
    return res.status(500).json({
      success: false,
      message: 'Error en el servidor',
      error:   process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// ─────────────────────────────────────────────
// OBTENER PERFIL DE BARBERO
// ─────────────────────────────────────────────
router.get('/barber/:barberId', async (req, res) => {
  try {
    const { barberId } = req.params;

    if (!mongoose.connection?.db) {
      return res.status(500).json({ success: false, message: 'Error de conexión con la base de datos' });
    }

    const db         = mongoose.connection.db;
    const collection = db.collection('barberos');

    let barbero;
    try {
      barbero = await collection.findOne({ _id: new ObjectId(barberId) });
    } catch {
      barbero = await collection.findOne({ barberId });
    }

    if (!barbero) {
      return res.status(404).json({ success: false, message: 'Barbero no encontrado' });
    }

    const { password, ...barberoData } = barbero;

    return res.status(200).json({ success: true, barber: barberoData });

  } catch (error) {
    console.error('Error obteniendo perfil de barbero:', error);
    return res.status(500).json({ success: false, message: 'Error interno del servidor' });
  }
});

// ─────────────────────────────────────────────
// OBTENER DATOS DE USUARIO
// ─────────────────────────────────────────────
router.get('/get-user/:userId', async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('-password');
    if (!user) return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    return res.json({ success: true, user });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// ─────────────────────────────────────────────
// ACTUALIZAR USUARIO NORMAL
// ─────────────────────────────────────────────
router.put('/update-user', async (req, res) => {
  try {
    const { userId, nombre, email, telefono, password } = req.body;

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ success: false, message: 'Usuario no encontrado' });

    if (nombre)   user.nombre   = nombre;
    if (email)    user.correo   = email;
    if (telefono) user.telefono = telefono;
    if (password) user.password = password; // El modelo hashea en pre-save

    await user.save();

    const updatedUser = user.toObject();
    delete updatedUser.password;

    return res.json({ success: true, message: 'Usuario actualizado', user: updatedUser });

  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// ─────────────────────────────────────────────
// ACTUALIZAR BARBERO
// ─────────────────────────────────────────────
router.put('/update-barber', async (req, res) => {
  try {
    const { barberId, nombre, telefono, passwordActual, passwordNueva } = req.body;

    if (!barberId) {
      return res.status(400).json({ success: false, message: 'Falta barberId' });
    }

    const db         = mongoose.connection.db;
    const collection = db.collection('barberos');

    const barbero = await collection.findOne({ _id: new ObjectId(barberId) });
    if (!barbero) {
      return res.status(404).json({ success: false, message: 'Barbero no encontrado' });
    }

    const $set = {};

    // Actualizar nombre con límite de 2 cambios cada 6 meses
    if (nombre && nombre !== barbero.nombre) {
      const cambios            = barbero.cambiosNombre ?? 0;
      const ultimoCambio       = barbero.ultimoCambioNombre ? new Date(barbero.ultimoCambioNombre) : null;
      const mesesTranscurridos = ultimoCambio
        ? (Date.now() - ultimoCambio.getTime()) / (1000 * 60 * 60 * 24 * 30)
        : 999;

      if (cambios >= 2 && mesesTranscurridos < 6) {
        return res.status(400).json({
          success: false,
          message: `Puedes cambiar tu nombre en ${Math.ceil(6 - mesesTranscurridos)} meses`
        });
      }

      $set.nombre             = nombre;
      $set.cambiosNombre      = mesesTranscurridos >= 6 ? 1 : cambios + 1;
      $set.ultimoCambioNombre = new Date();
    }

    if (telefono) $set.telefono = telefono;

    // Cambiar contraseña con bcrypt
    if (passwordActual && passwordNueva) {
      const passwordValida = await comparePassword(passwordActual, barbero.password);
      if (!passwordValida) {
        return res.status(401).json({ success: false, message: 'La contraseña actual es incorrecta' });
      }
      if (passwordNueva.length < 6) {
        return res.status(400).json({ success: false, message: 'La nueva contraseña debe tener al menos 6 caracteres' });
      }
      $set.password = await hashPassword(passwordNueva);
    }

    if (Object.keys($set).length === 0) {
      return res.status(400).json({ success: false, message: 'No hay cambios que guardar' });
    }

    await collection.updateOne({ _id: new ObjectId(barberId) }, { $set });

    return res.status(200).json({ success: true, message: 'Perfil actualizado' });

  } catch (error) {
    console.error('Error update-barber:', error);
    return res.status(500).json({ success: false, message: 'Error del servidor' });
  }
});

module.exports = router;