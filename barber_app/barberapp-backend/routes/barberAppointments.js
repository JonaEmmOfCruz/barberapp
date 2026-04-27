const express = require('express');
const router = express.Router();
const appointmentController = require('../controllers/barberAppointmentController');

// Ruta para el botón "IR"
// El método es PUT porque estamos actualizando datos existentes
router.put('/start-trip/:idCita', appointmentController.startTrip);

// Ruta para llegada automática por GPS
router.put('/arrive/:idCita', appointmentController.arriveAtDestination);

// Ruta para el botón "FINALIZAR"
router.put('/finish/:idCita', appointmentController.finishService);

// Citas del barbero por fecha (Flutter Agenda screen)
router.get('/barbero/:barberId', appointmentController.getCitasBarbero);

// Responder solicitud de cita (aceptar / rechazar / reagendar)
router.put('/:idCita/responder', appointmentController.responderSolicitud);

module.exports = router;