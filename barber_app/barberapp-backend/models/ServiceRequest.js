const mongoose = require('mongoose')

const serviceRequestSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        require: true
    },

    tipoServicioGeneral: {
        type: String,
        enum: ['propio', 'segundo'],
        require: true
    },

    servicios: [{
        type: String,
        enum: ['Corte', 'Barba', 'Tinte', 'Combo', 'Cejas']
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

    costoEstimado: Number,
    fechaCreacion: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('ServiceRequest', serviceRequestSchema);