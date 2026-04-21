// Ejemplo de endpoint para guardar documentos
const { barberId, vehicleType, vehicleBrand, vehiclePlate } = req.body;

const docCollection = cachedDb.collection("barberDocuments");

await docCollection.updateOne(
  { barberId: barberId }, // Filtro: busca por el ID del barbero
  { 
    $set: { 
      vehicleType,
      vehicleBrand,
      vehiclePlate,
      // Aquí irían las URLs de las fotos que subas
      actualizado: new Date()
    } 
  },
  { upsert: true } // Si no existe, lo crea
);