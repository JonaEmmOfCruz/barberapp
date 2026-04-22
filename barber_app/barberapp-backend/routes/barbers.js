// routes/barbers.js
const express = require('express');
const router = express.Router();
const Barbero = require('../models/Barbero');

// GET: /api/barbers (Tu ruta original)
router.get('/', async (req, res) => {
  try {
    console.log("🔍 Buscando barberos en la colección...");
    
    // Busca todos los documentos en la colección 'barberos'
    const barbers = await Barbero.find();
    
    console.log(`✅ Se encontraron ${barbers.length} barberos en la base de datos.`);
    res.status(200).json(barbers);
  } catch (error) {
    console.error("❌ Error al consultar los barberos:", error);
    res.status(500).json({ message: "Error interno del servidor" });
  }
});

// ==========================================
// NUEVAS RUTAS PARA FAVORITOS
// ==========================================

// 1. GET: Obtener solo los favoritos de UN usuario específico (Para el Home)
router.get('/favorites/:userId', async (req, res) => {
  try {
    console.log(`🔍 Buscando barberos favoritos para el usuario: ${req.params.userId}`);
    // Busca los barberos que contengan este userId dentro de su arreglo favoritedBy
    const favoritos = await Barbero.find({ favoritedBy: req.params.userId });
    res.status(200).json(favoritos);
  } catch (error) {
    console.error("❌ Error al obtener favoritos:", error);
    res.status(500).json([]); // Devolvemos un arreglo vacío para que Flutter no falle
  }
});

// 2. POST: Marcar como favorito (Añade el userId al barbero)
router.post('/favorite', async (req, res) => {
  const { barberId, userId } = req.body;
  try {
    console.log(`⭐ Agregando usuario ${userId} a favoritos del barbero ${barberId}`);
    // $addToSet agrega el ID sin duplicarlo
    await Barbero.findByIdAndUpdate(barberId, { $addToSet: { favoritedBy: userId } });
    res.status(200).json({ message: "Añadido a favoritos" });
  } catch (error) {
    console.error("❌ Error al añadir a favoritos:", error);
    res.status(500).json({ message: "Error al añadir a favoritos" });
  }
});

// 3. DELETE: Quitar de favoritos (Saca el userId del barbero)
router.delete('/favorite', async (req, res) => {
  const { barberId, userId } = req.body;
  try {
    console.log(`💔 Quitando usuario ${userId} de favoritos del barbero ${barberId}`);
    // $pull quita el ID del arreglo
    await Barbero.findByIdAndUpdate(barberId, { $pull: { favoritedBy: userId } });
    res.status(200).json({ message: "Quitado de favoritos" });
  } catch (error) {
    console.error("❌ Error al quitar de favoritos:", error);
    res.status(500).json({ message: "Error al quitar de favoritos" });
  }
});

module.exports = router;