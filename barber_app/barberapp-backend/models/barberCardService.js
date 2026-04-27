const mongoose = require('mongoose');

const ServiceCardSchema = new mongoose.Schema({
  barberId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'barberos', 
    required: true
  },
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User', 
    required: true
  },
  tipo: { 
    type: String, 
    enum: ['Runner', 'Cita'], 
    required: true 
  },
  servicios: {
    type: String, 
    required: true
  },
  ganancia: {
    type: Number, 
    required: true,
    default: 0
  },
  status: {
    type: String,
    enum: ['pendiente', 'en_camino', 'en_proceso', 'finalizado'], 
    default: 'pendiente'
  },
  // MÉTRICAS DE LOGÍSTICA Y TIEMPO
  fecha: {
    type: Date,
    default: Date.now 
  },
  horaSalida: { 
    type: Date // Se guarda al presionar "IR"
  },
  horaLlegada: { 
    type: Date // Se guarda automáticamente por GPS
  },
  horaInicio: {
    type: Date // Se marca cuando el barbero empieza realmente el corte
  },
  horaFin: {
    type: Date // Se guarda cuando el barbero pica "Terminar"
  },
  duracionTotalMinutos: {
    type: Number, 
    default: 0
  }
}, { timestamps: true });

// Middleware para calcular la duración automáticamente antes de guardar
ServiceCardSchema.pre('save', function(next) {
  // Calculamos la duración real del servicio (Corte)
  // Usamos horaLlegada (o horaInicio) hasta horaFin
  if (this.horaLlegada && this.horaFin) {
    const diferencia = this.horaFin - this.horaLlegada; 
    this.duracionTotalMinutos = Math.round(diferencia / 60000); 
  }
  next();
});

module.exports = mongoose.model('BarberServiceCard', ServiceCardSchema);