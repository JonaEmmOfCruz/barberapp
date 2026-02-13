const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const User = require('../models/User');

// Configurar multer para guardar imágenes
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/profile-images';
    // Crear el directorio si no existe
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'profile-' + uniqueSuffix + ext);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Solo imágenes (jpeg, jpg, png, gif)'));
    }
  }
});

// Ruta para subir imagen de perfil
router.post('/profile-image', upload.single('image'), async (req, res) => {
  try {
    console.log('Recibida petición de subida de imagen');
    console.log('Body:', req.body);
    console.log('File:', req.file);
    
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ message: 'userId es requerido' });
    }
    
    if (!req.file) {
      return res.status(400).json({ message: 'No se recibió ninguna imagen' });
    }
    
    // Construir URL de la imagen
    const imageUrl = `/uploads/profile-images/${req.file.filename}`;
    
    // Actualizar usuario con la URL de la imagen
    const usuario = await User.findByIdAndUpdate(
      userId,
      { profileImage: imageUrl },
      { new: true }
    );
    
    if (!usuario) {
      return res.status(404).json({ message: 'Usuario no encontrado' });
    }
    
    console.log('Imagen subida exitosamente para usuario:', userId);
    
    res.json({
      success: true,
      message: 'Imagen subida exitosamente',
      imageUrl: imageUrl
    });
    
  } catch (error) {
    console.error('Error al subir imagen:', error);
    res.status(500).json({ 
      message: 'Error al subir imagen',
      error: error.message 
    });
  }
});

module.exports = router;