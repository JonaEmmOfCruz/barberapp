const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const barberoSchema = new mongoose.Schema({
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
  experiencia: {
    años: { type: Number, default: 0 },
    servicios: [String],
    pdf: { type: String, default: null }
  },
  vehiculo: [String],
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

barberoSchema.pre('save', async function(next) {
  const barbero = this;
  
  if (!barbero.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    barbero.password = await bcrypt.hash(barbero.password, salt);
    next();
  } catch (err) {
    next(err);
  }
});

barberoSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('Barbero', barberoSchema);