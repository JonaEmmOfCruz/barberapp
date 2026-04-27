const mongoose = require('mongoose');

const AgendaSlotSchema = new mongoose.Schema({

  barberId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Barber',
    required: true,
    index: true
  },

  // Referencia a la jornada que generó este slot
  jornadaId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BarberJornada',
    default: null
  },

  fecha:       { type: String, required: true, index: true },
  hora:        { type: String, required: true },
  horaMinutos: { type: Number, required: true },

  status: {
    type: String,
    enum: [
      'disponible',  // libre, el cliente puede agendar
      'ocupado',     // tiene cita agendada
      'descanso',    // bloqueado por pausa del barbero
      'bloqueado',   // bloqueado por conflicto híbrido runner
      'pasado'       // ya pasó la hora
    ],
    default: 'disponible'
  },

  // Si está ocupado
  appointmentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Appointment',
    default: null
  },
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },

  // Duración del servicio agendado en este slot (en minutos)
  // Se calcula al momento de que el cliente agenda
  duracionEstimadaMin: { type: Number, default: null },

}, {
  timestamps: true,
  versionKey: false
});

AgendaSlotSchema.index({ barberId: 1, fecha: 1 });
AgendaSlotSchema.index({ barberId: 1, fecha: 1, status: 1 });

AgendaSlotSchema.statics.horaAMinutos = function(hora) {
  const [h, m] = hora.split(':').map(Number);
  return h * 60 + m;
};

AgendaSlotSchema.statics.minutosAHora = function(minutos) {
  const h = Math.floor(minutos / 60).toString().padStart(2, '0');
  const m = (minutos % 60).toString().padStart(2, '0');
  return `${h}:${m}`;
};

module.exports = mongoose.model('AgendaSlot', AgendaSlotSchema, 'agendaSlots');