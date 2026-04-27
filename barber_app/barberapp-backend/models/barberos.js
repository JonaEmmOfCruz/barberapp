const mongoose = require('mongoose');

// ─────────────────────────────────────────────
//  TIEMPOS DEFAULT POR SERVICIO (Fase 1)
//  Cuando el barbero es nuevo (<10 servicios)
//  usamos estos valores en minutos.
//  Cuando ya tiene métricas propias, se ignoran.
// ─────────────────────────────────────────────
const TIEMPOS_DEFAULT = {
  'Corte':              50,
  'Corte + Barba':      100,
  'Corte + Barba + Ceja': 120,
  'Barba':              30,
  'Ceja':               15,
};

const BarberSchema = new mongoose.Schema({

  // ── Campos existentes de la web (NO TOCAR) ──────────────────────────
  nombre:       String,
  email:        String,
  telefono:     String,
  ciudad:       String,
  experiencia:  Number,
  especialidad: String,
  usuario:      String,
  password:     String,
  terminos:     Boolean,
  estado:       String,
  fechaRegistro: Date,
  favoritedBy:  [mongoose.Schema.Types.ObjectId],

  // ── Campos que ya tenías en la app móvil ────────────────────────────
  isAvailable:  { type: Boolean, default: false },
  isWorking:    { type: Boolean, default: false },
  workMode: {
    type: String,
    enum: ['offline', 'runner', 'agenda', 'hibrido'],
    default: 'offline'
  },
  lastLocation: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null }
  },
  favoritos: [{ type: mongoose.Schema.Types.ObjectId }],

  // ── NUEVO: Métricas para cálculo de tiempo de servicio ──────────────
  // Se actualiza automáticamente al finalizar cada servicio.
  metricas: {
    totalServicios:        { type: Number, default: 0 },
    // Promedio real en minutos (null = aún no hay suficientes datos)
    promedioServicioMin:   { type: Number, default: null },
    // Breakdown por tipo de servicio para mayor precisión
    porTipo: {
      type: Map,
      of: new mongoose.Schema({
        cantidad:  { type: Number, default: 0 },
        promedioMin: { type: Number, default: null }
      }, { _id: false }),
      default: {}
    }
  },

  // ── NUEVO: Config de agenda del día ─────────────────────────────────
  // El barbero activa slots desde la app. Se resetea cada día.
  agendaHoy: {
    fecha:        { type: String, default: null }, // "YYYY-MM-DD"
    slotsActivos: { type: [String], default: [] }  // ["10:00","10:30","11:00"]
  }

}, {
  versionKey: false,
  strict: false  // ← CLAVE: permite que los campos extra de la web coexistan
});

// ─────────────────────────────────────────────
//  MÉTODO ESTÁTICO: obtener tiempo estimado
//  para un barbero dado un tipo de servicio.
//  Aplica lógica de Fase 1 / Fase 2.
// ─────────────────────────────────────────────
BarberSchema.statics.getTiempoEstimado = function(barber, tipoServicio) {
  const UMBRAL_METRICAS = 10; // servicios mínimos para usar datos reales

  // Fase 2: el barbero ya tiene suficientes métricas
  if (barber.metricas && barber.metricas.totalServicios >= UMBRAL_METRICAS) {
    const breakdown = barber.metricas.porTipo;
    if (breakdown && breakdown.get && breakdown.get(tipoServicio)) {
      const dato = breakdown.get(tipoServicio);
      if (dato.promedioMin) return dato.promedioMin;
    }
    // Fallback: promedio general del barbero
    if (barber.metricas.promedioServicioMin) {
      return barber.metricas.promedioServicioMin;
    }
  }

  // Fase 1: usar defaults del sistema
  return TIEMPOS_DEFAULT[tipoServicio] ?? 35; // 35 min si no coincide ningún tipo
};

// ─────────────────────────────────────────────
//  MÉTODO ESTÁTICO: calcular workMode
//  basado en isAvailable + slotsActivos
// ─────────────────────────────────────────────
BarberSchema.statics.calcularWorkMode = function(isAvailable, tieneSlotsActivos) {
  if (!isAvailable && !tieneSlotsActivos) return 'offline';
  if (isAvailable  && !tieneSlotsActivos) return 'runner';
  if (!isAvailable && tieneSlotsActivos)  return 'agenda';
  if (isAvailable  && tieneSlotsActivos)  return 'hibrido';
  return 'offline';
};

module.exports = mongoose.model('Barber', BarberSchema, 'barberos');
module.exports.TIEMPOS_DEFAULT = TIEMPOS_DEFAULT;