const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  nombre: { type: String, required: true, trim: true },
  correo: { type: String, required: true, unique: true, lowercase: true, trim: true },
  telefono: { type: String, required: true },
  password: { type: String, required: true },
  profileImage: { type: String, default: null },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// Middleware para encriptar - VERSIÓN CORREGIDA (SIN next)
userSchema.pre('save', async function() {
  try {
    // Si la contraseña no ha sido modificada, salir
    if (!this.isModified('password')) {
      return;
    }
    
    console.log('🔐 Encriptando contraseña para:', this.correo);
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    console.log('✅ Contraseña encriptada');
    
    // No necesitas llamar next() - Mongoose espera una promesa
  } catch (error) {
    console.error('❌ Error encriptando:', error);
    // Lanza el error para que Mongoose lo maneje
    throw error;
  }
});

// Método para comparar contraseñas
userSchema.methods.comparePassword = async function(candidatePassword) {
  try {
    return await bcrypt.compare(candidatePassword, this.password);
  } catch (error) {
    console.error('Error comparando contraseñas:', error);
    return false;
  }
};

module.exports = mongoose.model('User', userSchema);