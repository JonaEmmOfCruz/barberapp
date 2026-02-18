const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  nombre: {
    type: String,
    required: true,
    trim: true
  },
  correo: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  telefono: {
    type: String,
    required: true
  },
  password: {
    type: String,
    required: true
  },
  profileImage: {
    type: String,
    default: null
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

// ✅ MIDDLEWARE PARA ENCRIPTAR CONTRASEÑA (VERSIÓN CORREGIDA)
userSchema.pre('save', async function(next) {
  try {
    // 'this' se refiere al documento que se está guardando
    const user = this;
    
    console.log('Middleware pre-save ejecutándose para:', user.correo);
    console.log('   ¿Contraseña modificada?', user.isModified('password'));
    
    // Solo encriptar si la contraseña ha sido modificada (o es nueva)
    if (!user.isModified('password')) {
      console.log('   Contraseña no modificada, saltando encriptación');
      return next();
    }
    
    // Verificar si la contraseña ya está encriptada (por si acaso)
    if (user.password.startsWith('$2a$') || user.password.startsWith('$2b$')) {
      console.log('   Contraseña ya parece estar encriptada, saltando');
      return next();
    }
    
    console.log('   Encriptando contraseña...');
    
    // Generar salt y encriptar
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(user.password, salt);
    
    // Asignar la contraseña encriptada
    user.password = hashedPassword;
    
    console.log('Contraseña encriptada exitosamente');
    next();
    
  } catch (error) {
    console.error('Error encriptando contraseña:', error);
    next(error);
  }
});

// Método para comparar contraseñas
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);