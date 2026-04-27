const express = require('express');
const router = express.Router();
const disponibilidadController = require('../controllers/barberDisponibilidadController');
const agendaController = require('../controllers/barberAgendaController');

// ═══════════════════════════════════════════════
//  DISPONIBILIDAD (Toggle + Estado)
// ═══════════════════════════════════════════════

// GET  /api/disponibilidad/:barberId/estado
// → Flutter lo llama en initState() del Home para rehidratar el estado
router.get('/:barberId/estado', disponibilidadController.getEstado);

// PUT  /api/disponibilidad/:barberId/toggle
// Body: { isAvailable: bool, lat?: number, lng?: number }
// → El barbero presiona el switch de disponibilidad
router.put('/:barberId/toggle', disponibilidadController.toggleDisponibilidad);

// PUT  /api/disponibilidad/:barberId/ubicacion
// Body: { lat: number, lng: number }
// → Actualización periódica de ubicación GPS (cada 30s aprox.)
router.put('/:barberId/ubicacion', disponibilidadController.actualizarUbicacion);

// ═══════════════════════════════════════════════
//  AGENDA (Slots del día)
// ═══════════════════════════════════════════════

// GET  /api/disponibilidad/:barberId/slots?fecha=YYYY-MM-DD
// → Carga la grilla de slots para mostrar en la screen de Agenda
router.get('/:barberId/slots', agendaController.getSlotsDelDia);



// POST /api/disponibilidad/:barberId/verificar-runner
// Body: { tiempoServicioMin, latCliente, lngCliente, latBarbero, lngBarbero }
// → El sistema verifica si el barbero puede aceptar un Runner en modo híbrido
router.post('/:barberId/verificar-runner', agendaController.verificarConflictoRunner);

// Agrega estas 3 líneas a las que ya tienes:
router.post('/:barberId/jornada', agendaController.abrirJornada);
router.get('/:barberId/jornadas', agendaController.getJornadasSemana);
router.delete('/:barberId/jornada/:jornadaId', agendaController.cerrarJornada);

module.exports = router;