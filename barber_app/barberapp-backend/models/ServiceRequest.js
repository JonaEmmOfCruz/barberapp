const mongoose = require('mongoose');

const serviceRequestSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true // Corregido 'require' por 'required'
    },

    tipoServicioGeneral: {
        type: String,
        enum: ['propio', 'segundo'],
        required: true // Corregido 'require' por 'required'
    },

    servicios: [{
        type: String,
        // He sincronizado estos valores con los nombres exactos de tu Flutter
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

    costoEstimado: Number,
    fechaCreacion: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('ServiceRequest', serviceRequestSchema);