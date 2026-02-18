const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const User = require('../models/User');

const router = express.Router();

// Asegurar que el directorio uploads existe
const uploadDir = path.join(__dirname, '../uploads/profile-images');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Configuración de Multer para almacenamiento
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // Generar nombre único para la imagen
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, 'profile-' + req.body.userId + '-' + uniqueSuffix + ext);
    }
});

// Filtro más permisivo - acepta cualquier archivo que parezca una imagen
const fileFilter = (req, file, cb) => {
    console.log('Tipo de archivo recibido:', file.mimetype);
    console.log('Nombre original:', file.originalname);
    
    // Lista amplia de tipos de imagen
    const imageMimeTypes = [
        'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 
        'image/webp', 'image/bmp', 'image/tiff', 'image/svg+xml',
        'image/heic', 'image/heif', 'image/ico', 'image/x-icon',
        'application/octet-stream', // Común en iOS Simulator
        'application/x-img', // Otro tipo común
        'image/x-ms-bmp', 'image/x-tiff', 'image/x-photoshop',
        'image/x-png', 'image/x-ico', 'image/x-icon',
        'image/vnd.microsoft.icon'
    ];
    
    // Extensiones permitidas
    const imageExtensions = [
        '.jpg', '.jpeg', '.png', '.gif', '.webp', 
        '.bmp', '.tiff', '.tif', '.svg', '.heic', 
        '.heif', '.ico', '.psd', '.ai', '.eps'
    ];
    
    const ext = path.extname(file.originalname).toLowerCase();
    const isImageByExtension = imageExtensions.includes(ext);
    const isImageByMime = imageMimeTypes.includes(file.mimetype);
    
    // Para iOS Simulator, aceptar prácticamente cualquier cosa
    const isIOSSimulator = req.headers['user-agent']?.includes('iPhone') || 
                           req.headers['user-agent']?.includes('iPad') ||
                           req.headers['origin']?.includes('localhost');
    
    if (isIOSSimulator) {
        console.log('iOS Simulator detectado - aceptando archivo');
        return cb(null, true);
    }
    
    if (isImageByExtension || isImageByMime) {
        console.log('Archivo aceptado como imagen');
        return cb(null, true);
    }
    
    // Si no estamos seguros, aceptamos de todas formas con advertencia
    console.log('Aceptando archivo con tipo no reconocido:', file.mimetype);
    cb(null, true); // Aceptar de todas formas
    
    // O si quieres rechazar los que no son imágenes:
    // cb(new Error('Solo se permiten imágenes'));
};

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB máximo
    fileFilter: fileFilter
});

// Ruta para subir imagen de perfil
router.post('/profile-image', upload.single('image'), async (req, res) => {
    try {
        console.log('Recibiendo solicitud de subida de imagen');
        console.log('Body:', req.body);
        console.log('File:', req.file);

        const { userId } = req.body;

        if (!userId) {
            return res.status(400).json({
                message: 'Se requiere el ID del usuario'
            });
        }

        if (!req.file) {
            return res.status(400).json({
                message: 'No se recibió ninguna imagen'
            });
        }

        // Buscar el usuario
        const user = await User.findById(userId);
        
        if (!user) {
            // Si el usuario no existe, eliminar la imagen subida
            fs.unlinkSync(req.file.path);
            return res.status(404).json({
                message: 'Usuario no encontrado'
            });
        }

        // Si el usuario ya tenía una imagen anterior, eliminarla
        if (user.profileImage) {
            const oldImagePath = path.join(__dirname, '..', user.profileImage);
            if (fs.existsSync(oldImagePath)) {
                fs.unlinkSync(oldImagePath);
                console.log('Imagen anterior eliminada:', oldImagePath);
            }
        }

        // Construir la URL de la imagen
        const imageUrl = `/uploads/profile-images/${req.file.filename}`;

        // Actualizar el usuario con la nueva imagen
        user.profileImage = imageUrl;
        await user.save();

        console.log('Usuario actualizado con imagen:', imageUrl);

        res.status(200).json({
            message: 'Imagen subida exitosamente',
            imageUrl: imageUrl
        });

    } catch (error) {
        console.error('Error al subir imagen:', error);
        
        // Si hay error y se subió un archivo, eliminarlo
        if (req.file) {
            try {
                fs.unlinkSync(req.file.path);
            } catch (unlinkError) {
                console.error('Error al eliminar archivo temporal:', unlinkError);
            }
        }

        res.status(500).json({
            message: 'Error al subir la imagen: ' + error.message
        });
    }
});

// Ruta para eliminar imagen de perfil
router.delete('/profile-image/:userId', async (req, res) => {
    try {
        const { userId } = req.params;

        const user = await User.findById(userId);
        
        if (!user) {
            return res.status(404).json({
                message: 'Usuario no encontrado'
            });
        }

        if (user.profileImage) {
            // Eliminar el archivo físico
            const imagePath = path.join(__dirname, '..', user.profileImage);
            if (fs.existsSync(imagePath)) {
                fs.unlinkSync(imagePath);
            }

            // Actualizar el usuario
            user.profileImage = null;
            await user.save();

            res.status(200).json({
                message: 'Imagen eliminada exitosamente'
            });
        } else {
            res.status(400).json({
                message: 'El usuario no tiene imagen de perfil'
            });
        }

    } catch (error) {
        console.error('Error al eliminar imagen:', error);
        res.status(500).json({
            message: 'Error al eliminar la imagen: ' + error.message
        });
    }
});

// Ruta para obtener la imagen de perfil
router.get('/profile-image/:userId', async (req, res) => {
    try {
        const { userId } = req.params;

        const user = await User.findById(userId);
        
        if (!user) {
            return res.status(404).json({
                message: 'Usuario no encontrado'
            });
        }

        if (!user.profileImage) {
            return res.status(404).json({
                message: 'El usuario no tiene imagen de perfil'
            });
        }

        res.status(200).json({
            imageUrl: user.profileImage
        });

    } catch (error) {
        console.error('Error al obtener imagen:', error);
        res.status(500).json({
            message: 'Error al obtener la imagen: ' + error.message
        });
    }
});

module.exports = router;