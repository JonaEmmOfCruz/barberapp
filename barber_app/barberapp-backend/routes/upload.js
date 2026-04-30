const express  = require('express');
const multer   = require('multer');
const path     = require('path');
const fs       = require('fs');
const mongoose = require('mongoose');
const User     = require('../models/User');

const router = express.Router();

// ─────────────────────────────────────────────
//  CARPETAS
// ─────────────────────────────────────────────
const profileDir = path.join(__dirname, '../uploads/profile-images');
const docsDir    = path.join(__dirname, '../uploads');

if (!fs.existsSync(profileDir)) fs.mkdirSync(profileDir, { recursive: true });
if (!fs.existsSync(docsDir))    fs.mkdirSync(docsDir,    { recursive: true });

// ─────────────────────────────────────────────
//  MULTER CONFIG
// ─────────────────────────────────────────────
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const docFields = [
            'profileImage', 'licenseImage',
            'ineFrente',    'ineReverso',
            'vehiclePhoto', 'platePhoto'
        ];
        cb(null, docFields.includes(file.fieldname) ? docsDir : profileDir);
    },
    filename: function (req, file, cb) {
        const ext    = path.extname(file.originalname);
        const unique = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const prefix = file.fieldname === 'image' ? `profile-${req.body.userId}` : 'barber';
        cb(null, `${prefix}-${unique}${ext}`);
    }
});

const upload = multer({ storage });

// ─────────────────────────────────────────────
//  FOTO PERFIL USUARIO
// ─────────────────────────────────────────────
router.post('/profile-image', upload.single('image'), async (req, res) => {
    try {
        const { userId } = req.body;
        if (!userId)    return res.status(400).json({ message: 'Se requiere userId' });
        if (!req.file) return res.status(400).json({ message: 'No se subió imagen' });

        const user = await User.findById(userId);
        if (!user) {
            fs.unlinkSync(req.file.path);
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        if (user.profileImage) {
            const oldPath = path.join(__dirname, '..', user.profileImage);
            if (fs.existsSync(oldPath)) fs.unlinkSync(oldPath);
        }

        const imageUrl     = `/uploads/profile-images/${req.file.filename}`;
        user.profileImage  = imageUrl;
        await user.save();

        res.json({ success: true, filePath: imageUrl });
    } catch (error) {
        if (req.file) fs.unlinkSync(req.file.path);
        res.status(500).json({ message: error.message });
    }
});

// ─────────────────────────────────────────────
//  ELIMINAR FOTO PERFIL USUARIO
// ─────────────────────────────────────────────
router.delete('/profile-image/:userId', async (req, res) => {
    try {
        const user = await User.findById(req.params.userId);
        if (!user)              return res.status(404).json({ message: 'Usuario no encontrado' });
        if (!user.profileImage) return res.status(400).json({ message: 'No tiene imagen' });

        const imagePath = path.join(__dirname, '..', user.profileImage);
        if (fs.existsSync(imagePath)) fs.unlinkSync(imagePath);

        user.profileImage = null;
        await user.save();

        res.json({ message: 'Imagen eliminada' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// ─────────────────────────────────────────────
//  OBTENER FOTO PERFIL USUARIO
// ─────────────────────────────────────────────
router.get('/profile-image/:userId', async (req, res) => {
    try {
        const user = await User.findById(req.params.userId);
        if (!user)              return res.status(404).json({ message: 'Usuario no encontrado' });
        if (!user.profileImage) return res.status(404).json({ message: 'Sin imagen' });
        res.json({ imageUrl: user.profileImage });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// ─────────────────────────────────────────────
//  DOCUMENTOS BARBERO — GUARDAR
// ─────────────────────────────────────────────
const barberFields = upload.fields([
    { name: 'profileImage', maxCount: 1 },
    { name: 'licenseImage', maxCount: 1 },
    { name: 'ineFrente',    maxCount: 1 }, // ← nuevo: INE frente
    { name: 'ineReverso',   maxCount: 1 }, // ← nuevo: INE reverso
    { name: 'vehiclePhoto', maxCount: 1 },
    { name: 'platePhoto',   maxCount: 1 }
]);

router.post('/barber-documents', barberFields, async (req, res) => {
    try {
        const {
            barberId,
            vehicleType,
            vehicleBrand,
            vehiclePlate,
            vehicleModel,  // ← nuevo
            vehicleYear,   // ← nuevo
            vehicleColor,  // ← nuevo
        } = req.body;

        if (!barberId) return res.status(400).json({ message: 'Falta barberId' });

        const getUrl = (field) =>
            req.files?.[field] ? `/uploads/${req.files[field][0].filename}` : null;

        // Solo actualizamos los campos que vienen — no pisamos los que no vienen
        const $set = { updatedAt: new Date() };

        if (vehicleType)  $set.vehicleType  = vehicleType;
        if (vehicleBrand) $set.vehicleBrand = vehicleBrand;
        if (vehiclePlate) $set.vehiclePlate = vehiclePlate;
        if (vehicleModel) $set.vehicleModel = vehicleModel;
        if (vehicleYear)  $set.vehicleYear  = vehicleYear;
        if (vehicleColor) $set.vehicleColor = vehicleColor;

        const profileImage = getUrl('profileImage');
        const licenseImage = getUrl('licenseImage');
        const ineFrente    = getUrl('ineFrente');
        const ineReverso   = getUrl('ineReverso');
        const vehiclePhoto = getUrl('vehiclePhoto');
        const platePhoto   = getUrl('platePhoto');

        if (profileImage) $set.profileImage = profileImage;
        if (licenseImage) $set.licenseImage = licenseImage;
        if (ineFrente)    $set.ineFrente    = ineFrente;
        if (ineReverso)   $set.ineReverso   = ineReverso;
        if (vehiclePhoto) $set.vehiclePhoto = vehiclePhoto;
        if (platePhoto)   $set.platePhoto   = platePhoto;

        const db = mongoose.connection.db;
        await db.collection('barberDocuments').updateOne(
            { barberId },
            { $set },
            { upsert: true }
        );

        res.json({ success: true, message: 'Documentos guardados' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// ─────────────────────────────────────────────
//  DOCUMENTOS BARBERO — OBTENER
// ─────────────────────────────────────────────
router.get('/barber-documents/:barberId', async (req, res) => {
    try {
        const { barberId } = req.params;
        const db           = mongoose.connection.db;
        const documents    = await db.collection('barberDocuments').findOne({ barberId });

        if (!documents) {
            return res.status(404).json({ success: false, message: 'No se encontraron documentos' });
        }

        res.json({ success: true, data: documents });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// ─────────────────────────────────────────────
//  PERFIL STATUS — verifica si el perfil está completo
// ─────────────────────────────────────────────
router.get('/barber-profile-status/:barberId', async (req, res) => {
    try {
        const { barberId } = req.params;
        const db  = mongoose.connection.db;
        const doc = await db.collection('barberDocuments').findOne({ barberId });

        const tipo = doc?.vehicleType ?? '';
        const esMotorizado = tipo === 'Auto' || tipo === 'Motocicleta';

        // Campos siempre obligatorios
        const campos = {
            profileImage: !!doc?.profileImage,
            vehicleType:  !!doc?.vehicleType,
            vehicleColor: !!doc?.vehicleColor,
            ineFrente:    !!doc?.ineFrente,
        };

        // Solo obligatorios si es motorizado
        if (esMotorizado) {
            campos.vehicleBrand  = !!doc?.vehicleBrand;
            campos.vehicleModel  = !!doc?.vehicleModel;
            campos.vehiclePlate  = !!doc?.vehiclePlate;
            campos.licenseImage  = !!doc?.licenseImage;
        }

        const perfilCompleto = Object.values(campos).every(v => v);

        res.status(200).json({
            success: true,
            perfilCompleto,
            camposFaltantes: Object.entries(campos)
                .filter(([_, v]) => !v)
                .map(([k]) => k)
        });
    } catch (error) {
        res.status(500).json({ success: false, msg: error.message });
    }
});
module.exports = router;