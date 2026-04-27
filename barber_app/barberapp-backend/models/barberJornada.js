const mongoose = require('mongoose');
 
// ─────────────────────────────────────────────
//  BarberJornada
//
//  Representa un día de trabajo que el barbero abre.
//  De aquí se generan los AgendaSlots automáticamente.
//
//  Ejemplo:
//  Barbero abre jornada: 2026-05-01, 09:00 → 14:00
//  Con descanso: 12:00 → 13:00
//  → Sistema genera slots: 9:00, 9:30, 10:00, 10:30, 11:00, 11:30, 13:00, 13:30
// ─────────────────────────────────────────────
 
const BarberJornadaSchema = new mongoose.Schema({
 
  barberId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Barber',
    required: true,
    index: true
  },
 
  // Fecha: "YYYY-MM-DD"
  fecha: {
    type: String,
    required: true,
    index: true
  },
 
  // Hora inicio y fin en minutos desde medianoche
  // Ej: 9:00 = 540, 14:00 = 840
  inicioMin: { type: Number, required: true },
  finMin:    { type: Number, required: true },
 
  // Hora inicio/fin como string "HH:MM" para mostrar en UI
  inicioHora: { type: String, required: true },
  finHora:    { type: String, required: true },
 
  // Descanso opcional
  descanso: {
    activo:     { type: Boolean, default: false },
    inicioMin:  { type: Number, default: null },
    finMin:     { type: Number, default: null },
    inicioHora: { type: String, default: null },
    finHora:    { type: String, default: null },
  },
 
  status: {
    type: String,
    enum: ['abierta', 'cerrada', 'cancelada'],
    default: 'abierta'
  },
 
  // Cuántos slots se generaron al abrir la jornada
  totalSlotsGenerados: { type: Number, default: 0 },
 
}, {
  timestamps: true,
  versionKey: false
});
 
// Índice único: un barbero solo puede tener una jornada por día
BarberJornadaSchema.index({ barberId: 1, fecha: 1 }, { unique: true });
 
module.exports = mongoose.model('BarberJornada', BarberJornadaSchema, 'barberJornadas');
 