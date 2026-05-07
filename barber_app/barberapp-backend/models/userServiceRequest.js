const mongoose = require('mongoose');

const serviceRequestSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    tipoServicioGeneral: {
        type: String,
        enum: ['propio', 'segundo'],
        required: true
    },
    servicios: [{
        type: String,
        enum: ['Corte', 'Barba', 'Ceja', 'Greka', 'Tinte', 'Combo']
    }],
    ubicacion: {
        direccion: String,
        coordenadas: {
            lat: Number,
            lng: Number
        }
    },
    estado: {
        type: String,
        enum: ['buscando', 'barbero_asignado', 'en_camino', 'en_servicio', 'finalizado', 'cancelado'],
        default: 'buscando'
    },
    barberoAsignado: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Barber',
        default: null
    },
    barberoId:    { type: String, default: null },
    barberoNombre: { type: String, default: null },
    costoEstimado: Number,
    
    horaLlegada:  { type: Date, default: null },
horaFin:      { type: Date, default: null },


distanciaKm:    { type: Number, default: null },
costoTotal:     { type: Number, default: null },
desglosePrecio: { type: Object, default: null },
calificado:     { type: Boolean, default: false },
}, {
    timestamps: true  // agrega createdAt y updatedAt automáticamente
});

module.exports = mongoose.model('ServiceRequest', serviceRequestSchema);