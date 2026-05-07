const mongoose = require('mongoose');

const BarberDisponibilidadSchema = new mongoose.Schema({
  barberId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Barber',
    required: true,
    unique: true
  },

  // Días recurrentes de la semana
  // 0=Domingo, 1=Lunes ... 6=Sábado
  diasDisponibles: [{
    dia:        { type: Number, required: true },
    inicioHora: { type: String, required: true }, // "09:00"
    finHora:    { type: String, required: true }, // "18:00"
  }],

  // Días específicos bloqueados
  diasBloqueados: [{
    fecha:  { type: String, required: true }, // "YYYY-MM-DD"
    motivo: { type: String, default: '' },
  }],

  // Duración por servicio (configurada manualmente hasta 10 servicios)
  duracionPorServicio: [{
    nombre:      { type: String, required: true }, // "Corte"
    duracionMin: { type: Number, default: 30 },
  }],

  // Indica si ya se pasó el umbral de 10 servicios
  // Si es true, se usa el promedio calculado del historial
  usarPromedioReal: { type: Boolean, default: false },

}, { timestamps: true, versionKey: false });

module.exports = mongoose.model('BarberDisponibilidad', BarberDisponibilidadSchema, 'barberDisponibilidad');