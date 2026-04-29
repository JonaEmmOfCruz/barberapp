// barberapp-backend/models/Favorite.js
const mongoose = require('mongoose');

const FavoriteSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },
  barberId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Barbero', // Asegúrate de que coincida con el nombre en Barbero.js
    required: true 
  },
}, { timestamps: true });

// Esto evita que un usuario agregue dos veces al mismo barbero
FavoriteSchema.index({ userId: 1, barberId: 1 }, { unique: true });

module.exports = mongoose.model('Favorite', FavoriteSchema);