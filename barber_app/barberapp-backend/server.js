const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

/* 
    Importar rutas 
*/
const authRoutes = require('./routes/auth');
const uploadRoutes = require('./routes/upload');

dotenv.config();

const app = express();

/* 
    Middleware 
*/
app.use(cors({
    origin: '*',
    credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({extended: true}));

/* 
    Archivos estaticos
*/
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

/* 
    Configuración de MongoDB según el usuario activo
*/
const getMongoConfig = () => {
    const activeUser = process.env.ACTIVE_USER || '1';
    console.log('ACTIVE_USER desde env:', activeUser);

    if (activeUser === '1') {
        return {
            uri: process.env.USER1_MONGO_URI,
            user: process.env.USER1_NAME
        };
    } else {
        return {
            uri: process.env.USER2_MONGO_URI,
            user: process.env.USER2_NAME
        };
    }
};

/* 
    Conexion con MongoDB - VERSIÓN CORREGIDA
*/
const connectDB = async () => {
    try {
        const dbConfig = getMongoConfig();
        
        console.log('=================================');
        console.log(`📱 Intentando conectar a MongoDB Atlas`);
        console.log(`👤 Usuario: ${dbConfig.user}`);
        console.log(`🔗 URI: ${dbConfig.uri.replace(/:[^:]*@/, ':****@')}`);
        console.log('=================================');
        
        // ⚠️ IMPORTANTE: Elimina useNewUrlParser y useUnifiedTopology
        // Ya no son necesarios en versiones recientes
        await mongoose.connect(dbConfig.uri);
        
        console.log('✅ Conectado exitosamente a MongoDB Atlas');
        console.log(`📊 Base de datos: ${mongoose.connection.name}`);
        
        mongoose.connection.on('error', err => {
            console.error('❌ Error en la conexión de MongoDB:', err);
        });
        
        mongoose.connection.on('disconnected', () => {
            console.log('⚠️ Desconectado de MongoDB');
        });
        
    } catch (error) {
        console.error('❌ Error al conectar a MongoDB Atlas:');
        console.error('   Nombre:', error.name);
        console.error('   Mensaje:', error.message);
        process.exit(1);
    }
};

connectDB();

/* 
    Rutas
*/
app.use('/api/auth', authRoutes);
app.use('/api/upload', uploadRoutes);

/* 
    Ruta de verificacion de los usuarios activos
*/
app.get('/api/config/active-user', (req, res) => {
    const dbConfig = getMongoConfig();
    res.json({
        activeUser: process.env.ACTIVE_USER || '1',
        user: dbConfig.user
    });
});

/* 
    Rutas de prueba
*/
app.get('/', (req, res) => {
    res.json({
        message: 'Api de BarberApp funcionando',
        activeUser: process.env.ACTIVE_USER || '1',
        timeStamp: new Date().toISOString()
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`✅ Servidor corriendo en el puerto: ${PORT}`);
    console.log(`🌐 Entorno: ${process.env.NODE_ENV || 'development'}`);
});