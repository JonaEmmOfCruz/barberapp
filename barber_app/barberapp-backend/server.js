const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

// 1. IMPORTAR RUTAS
const disponibilidadRoutes = require('./routes/barberDisponibilidad');
const serviceRoutes        = require('./routes/barberServiceRoute');
const authRoutes           = require('./routes/auth');
const uploadRoutes         = require('./routes/upload');
const serviceRequests      = require('./routes/userServiceRequests');
const appointmentRoutes    = require('./routes/barberAppointments');
const barbersRoutes        = require('./routes/userBarbers');       

dotenv.config();
const app = express();

// 2. MIDDLEWARES
app.use(cors({
    origin: '*',
    credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Archivos estáticos para fotos de cortes/perfil
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 3. CONFIGURACIÓN DE MONGODB
const getMongoConfig = () => {
    const activeUser = process.env.ACTIVE_USER || '1';
    if (activeUser === '1') {
        return { uri: process.env.USER1_MONGO_URI, user: process.env.USER1_NAME };
    } else if (activeUser === '2') {
        return { uri: process.env.USER2_MONGO_URI, user: process.env.USER2_NAME };
    } else {
        return { uri: process.env.USER3_MONGO_URI, user: process.env.USER3_NAME };
    }
};

const connectDB = async () => {
    try {
        const dbConfig = getMongoConfig();
        console.log('=================================');
        console.log(`👤 Usuario Activo: ${dbConfig.user}`);
        await mongoose.connect(dbConfig.uri);
        console.log('✅ Conectado exitosamente a MongoDB');
        console.log('=================================');
    } catch (error) {
        console.error('❌ Error de conexión:', error.message);
        process.exit(1);
    }
};

connectDB();

// 4. DEFINICIÓN DE RUTAS
app.use('/api/auth',             authRoutes);
app.use('/api/upload',           uploadRoutes);
app.use('/api/servicios',        serviceRoutes);
app.use('/api/service-requests', serviceRequests);
app.use('/api/disponibilidad',   disponibilidadRoutes);
app.use('/api/citas',            appointmentRoutes);
app.use('/api/barbers',          barbersRoutes);         // de tu colega
app.use('/api/reservas',         require('./routes/userReservas')); // de tu colega

// Ruta de prueba
app.get('/', (req, res) => {
    res.json({
        message: 'Api de BarberApp funcionando',
        activeUser: process.env.ACTIVE_USER || '1',
        timeStamp: new Date().toISOString()
    });
});

// 5. ENCENDER SERVIDOR
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en el puerto: ${PORT}`);
    console.log(`🔗 URL: http://localhost:${PORT}`);
});