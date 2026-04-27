const express = require('express');
const router = express.Router();
// Importamos el controlador (lo crearemos en el siguiente paso)
const serviceController = require('../controllers/barberServiceController');

// RUTA 1: Cuando el barbero acepta un servicio (Inicia el tiempo)
router.post('/aceptar', serviceController.aceptarServicio);

// RUTA 2: Cuando el barbero termina el servicio (Guarda ganancia y calcula tiempo)
router.put('/finalizar/:id', serviceController.finalizarServicio);

// RUTA 3: Para obtener las ganancias (Hoy, Semana, Mes)
router.get('/stats/:barberId', serviceController.getStats);

module.exports = router;