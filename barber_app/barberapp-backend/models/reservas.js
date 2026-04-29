const mongoose = require('mongoose');

const ReservaSchema = new mongoose.Schema({
  // Referencia al usuario que reserva
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  // Referencia al barbero (obtenido de tu modelo 'barberos')
  barberId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Barber',
    required: true
  },
  // Fecha de la cita (ISO Date)
  fecha: {
    type: Date,
    required: true
  },
  // Hora seleccionada (ej: "10:00 AM")
  hora: {
    type: String,
    required: true
  },
  // Estado de la reserva
  status: {
    type: String,
    enum: ['pendiente', 'confirmada', 'cancelada', 'completada'],
    default: 'pendiente'
  },
  // Fecha en que se creó el registro
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Reserva', ReservaSchema);