const mongoose = require('mongoose');

const AppointmentSchema = new mongoose.Schema({
    // El _id lo pone MongoDB solito, no hay que declararlo.

    barberId: { 
        type: mongoose.Schema.Types.ObjectId, 
        ref: 'Barber', 
        required: true 
    },
    
    // IMPORTANTE: El ID del cliente para saber a quién vas a atender
    clientId: { 
        type: mongoose.Schema.Types.ObjectId, 
        ref: 'Usuarios', // O como se llame tu colección de clientes
        required: true 
    },

    clienteNombre: String,
    domicilio: String,
    lat: Number,
    lng: Number,
    precioTotal: Number,

    // Tiempos para la Screen de Servicios y el Top Barberos
    horaProgramada: Date,
    horaSalida: Date,
    horaLlegada: Date,
    horaFin: Date,

    status: { 
        type: String, 
        enum: ['solicitud', 'aceptada', 'en_camino', 'finalizada', 'rechazada'], 
        default: 'solicitud' 
    }
}, { timestamps: true });

module.exports = mongoose.model('Appointment', AppointmentSchema);