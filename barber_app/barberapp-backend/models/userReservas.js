const mongoose = require('mongoose');

const ReservaSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  barberId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true
  },
  fecha: {
    type: String, // "YYYY-MM-DD" — mismo formato que los slots
    required: true
  },
  hora: {
    type: String, // "HH:MM"
    required: true
  },
  servicios: {
    type: [String],
    default: []
  },
  domicilio: { type: String,  default: '' },
lat:       { type: Number,  default: null },
lng:       { type: Number,  default: null },
  status: {
    type: String,
    enum: ['pendiente', 'aceptada', 'rechazada', 'reagendada', 'cancelada', 'completada'],
    default: 'pendiente'
  }
}, { timestamps: true });

module.exports = mongoose.model('Reserva', ReservaSchema, 'userReservas');