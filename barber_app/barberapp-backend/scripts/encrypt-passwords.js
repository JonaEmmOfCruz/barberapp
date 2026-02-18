// scripts/fix-passwords-urgent.js
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

// Configuración de MongoDB
const getMongoConfig = () => {
    const activeUser = process.env.ACTIVE_USER || '1';
    return {
        uri: activeUser === '1' ? process.env.USER1_MONGO_URI : process.env.USER2_MONGO_URI
    };
};

async function fixPasswords() {
    try {
        console.log('🔌 Conectando a MongoDB Atlas...');
        const dbConfig = getMongoConfig();
        await mongoose.connect(dbConfig.uri);
        console.log('✅ Conectado a MongoDB Atlas');
        
        // Obtener la colección directamente
        const db = mongoose.connection.db;
        const usersCollection = db.collection('users');
        
        // Buscar todos los usuarios
        const users = await usersCollection.find({}).toArray();
        console.log(`📊 Encontrados ${users.length} usuarios`);
        
        let fixed = 0;
        
        for (const user of users) {
            // Verificar si la contraseña ya está encriptada
            const isHashed = user.password && (user.password.startsWith('$2a$') || user.password.startsWith('$2b$'));
            
            console.log(`\n👤 Usuario: ${user.correo}`);
            console.log(`   Contraseña actual: ${user.password}`);
            console.log(`   ¿Encriptada? ${isHashed ? 'Sí' : 'No'}`);
            
            if (!isHashed && user.password) {
                // Encriptar la contraseña
                const salt = await bcrypt.genSalt(10);
                const hashedPassword = await bcrypt.hash(user.password, salt);
                
                // Actualizar en la base de datos
                await usersCollection.updateOne(
                    { _id: user._id },
                    { $set: { password: hashedPassword } }
                );
                
                console.log(`   ✅ Contraseña encriptada: ${hashedPassword.substring(0, 30)}...`);
                fixed++;
            }
        }
        
        console.log('\n📈 RESUMEN:');
        console.log(`   Usuarios corregidos: ${fixed}`);
        
    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await mongoose.disconnect();
        console.log('🔌 Desconectado');
    }
}

fixPasswords();