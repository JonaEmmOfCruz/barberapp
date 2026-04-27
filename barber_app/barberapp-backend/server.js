const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

// 1. IMPORTAR RUTAS (Enfoque Barbero)
const disponibilidadRoutes = require('./routes/barberDisponibilidad');
const serviceRoutes = require('./routes/barberServiceRoute'); 
const authRoutes = require('./routes/auth');
const uploadRoutes = require('./routes/upload');
const serviceRequests = require('./routes/serviceRequests');
const appointmentRoutes = require('./routes/barberAppointments');

dotenv.config();
const app = express();

// 2. MIDDLEWARES
app.use(cors({
    origin: '*',
    credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({extended: true}));

// Archivos estáticos para fotos de cortes/perfil
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 3. CONFIGURACIÓN DE MONGODB (Tu lógica multi-DB)
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

// 4. DEFINICIÓN DE RUTAS (API)
app.use('/api/auth', authRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/servicios', serviceRoutes); // Lógica de ganancias y tiempos del barbero
app.use('/api/service-requests', serviceRequests);
app.use('/api/disponibilidad', disponibilidadRoutes);
app.use('/api/citas', appointmentRoutes);

// Ruta de prueba
app.get('/', (req, res) => {
    res.json({
        message: 'Api de BarberApp funcionando',
        activeUser: process.env.ACTIVE_USER || '1',
        timeStamp: new Date().toISOString()
    });
});

// 5. ENCENDER SERVIDOR (Una sola vez)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en el puerto: ${PORT}`);
    console.log(`🔗 URL: http://localhost:${PORT}`);
});