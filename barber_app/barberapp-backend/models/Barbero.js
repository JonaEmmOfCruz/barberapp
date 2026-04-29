const mongoose = require('mongoose');

const barberoSchema = new mongoose.Schema({
  name: { type: String, required: true },
  // 👇 AGREGAMOS ESTO: Arreglo de IDs de usuarios que aman a este barbero
  favoritedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }]
}, {
  collection: 'barberos', 
  strict: false 
});

module.exports = mongoose.model('Barbero', barberoSchema);