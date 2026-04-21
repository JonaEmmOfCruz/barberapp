const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');
const User = require('../models/User');

const router = express.Router();

// =====================
// 📁 CREAR CARPETAS
// =====================
const profileDir = path.join(__dirname, '../uploads/profile-images');
const docsDir = path.join(__dirname, '../uploads');

if (!fs.existsSync(profileDir)) {
    fs.mkdirSync(profileDir, { recursive: true });
}

if (!fs.existsSync(docsDir)) {
    fs.mkdirSync(docsDir, { recursive: true });
}

// =====================
// ⚙️ MULTER CONFIG GLOBAL
// =====================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        // Si viene de documentos
        if (file.fieldname === 'profileImage' ||
            file.fieldname === 'licenseImage' ||
            file.fieldname === 'vehiclePhoto' ||
            file.fieldname === 'platePhoto') {
            cb(null, docsDir);
        } else {
            cb(null, profileDir);
        }
    },
    filename: function (req, file, cb) {
        const ext = path.extname(file.originalname);
        const unique = Date.now() + '-' + Math.round(Math.random() * 1E9);

        if (file.fieldname === 'image') {
            cb(null, `profile-${req.body.userId}-${unique}${ext}`);
        } else {
            cb(null, `barber-${unique}${ext}`);
        }
    }
});

const upload = multer({ storage });

// =====================
// 🖼️ SUBIR FOTO PERFIL
// =====================
router.post('/profile-image', upload.single('image'), async (req, res) => {
    try {
        const { userId } = req.body;

        if (!userId) {
            return res.status(400).json({ message: 'Se requiere userId' });
        }

        if (!req.file) {
            return res.status(400).json({ message: 'No se subió imagen' });
        }

        const user = await User.findById(userId);

        if (!user) {
            fs.unlinkSync(req.file.path);
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        // borrar anterior
        if (user.profileImage) {
            const oldPath = path.join(__dirname, '..', user.profileImage);
            if (fs.existsSync(oldPath)) fs.unlinkSync(oldPath);
        }

        const imageUrl = `/uploads/profile-images/${req.file.filename}`;
        user.profileImage = imageUrl;
        await user.save();

        res.json({ success: true, filePath: imageUrl });

    } catch (error) {
        if (req.file) fs.unlinkSync(req.file.path);
        res.status(500).json({ message: error.message });
    }
});

// =====================
// ❌ ELIMINAR FOTO PERFIL
// =====================
router.delete('/profile-image/:userId', async (req, res) => {
    try {
        const user = await User.findById(req.params.userId);

        if (!user) return res.status(404).json({ message: 'Usuario no encontrado' });

        if (!user.profileImage) {
            return res.status(400).json({ message: 'No tiene imagen' });
        }

        const imagePath = path.join(__dirname, '..', user.profileImage);
        if (fs.existsSync(imagePath)) fs.unlinkSync(imagePath);

        user.profileImage = null;
        await user.save();

        res.json({ message: 'Imagen eliminada' });

    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// =====================
// 📥 OBTENER FOTO PERFIL
// =====================
router.get('/profile-image/:userId', async (req, res) => {
    try {
        const user = await User.findById(req.params.userId);

        if (!user) return res.status(404).json({ message: 'Usuario no encontrado' });

        if (!user.profileImage) {
            return res.status(404).json({ message: 'Sin imagen' });
        }

        res.json({ imageUrl: user.profileImage });

    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// =====================
// 📄 DOCUMENTOS BARBERO
// =====================
const barberFields = upload.fields([
    { name: 'profileImage', maxCount: 1 },
    { name: 'licenseImage', maxCount: 1 },
    { name: 'vehiclePhoto', maxCount: 1 },
    { name: 'platePhoto', maxCount: 1 }
]);

router.post('/barber-documents', barberFields, async (req, res) => {
    try {
        const { barberId, vehicleType, vehicleBrand, vehiclePlate } = req.body;

        if (!barberId) {
            return res.status(400).json({ message: 'Falta barberId' });
        }

        const getUrl = (field) =>
            req.files[field] ? `/uploads/${req.files[field][0].filename}` : null;

        const data = {
            barberId,
            vehicleType,
            vehicleBrand,
            vehiclePlate,
            profileImage: getUrl('profileImage'),
            licenseImage: getUrl('licenseImage'),
            vehiclePhoto: getUrl('vehiclePhoto'),
            platePhoto: getUrl('platePhoto'),
            updatedAt: new Date()
        };

        const db = mongoose.connection.db;

        await db.collection('barberDocuments').updateOne(
            { barberId },
            { $set: data },
            { upsert: true }
        );

        res.json({ success: true, message: 'Documentos guardados' });

    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Ruta para obtener la documentación de un barbero
router.get('/barber-documents/:barberId', async (req, res) => {
    try {
        const { barberId } = req.params;
        const db = mongoose.connection.db;

        // Buscamos en la colección que creamos antes
        const documents = await db.collection('barberDocuments').findOne({ barberId: barberId });

        if (!documents) {
            return res.status(404).json({ success: false, message: "No se encontraron documentos" });
        }

        res.json({ success: true, data: documents });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;