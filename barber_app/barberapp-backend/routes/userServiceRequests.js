const express = require('express')
const router = express.Router()
const ServiceRequest = require('../models/userServiceRequest')
const { calcularPrecio } = require('../config/precios');
const Barber = require('../models/barberos');

router.post('/', async (req, res) => {
    try {
        const { userId, tipo, servicios, ubicacion } = req.body;

        if (!userId || !tipo || !servicios || servicios.length === 0) {
            return res.status(400).json({ error: 'Falta datos obligatorios' });
        }

        const newRequest = new ServiceRequest({
            userId,
            tipoServicioGeneral: tipo,
            servicios,
            ubicacion: {
                direccion: ubicacion.direccion,
                coordenadas: ubicacion.coordenadas
            },
            estado: 'buscando'
        });

        const savedRequest = await newRequest.save();

        // Buscar barberos disponibles en modo runner
        const mongoose = require('mongoose');
        const db       = mongoose.connection.db;

        const barberos = await db.collection('barberos').find({
            isAvailable: true,
            workMode:    { $in: ['runner', 'hibrido'] },
            'lastLocation.lat': { $exists: true, $ne: null },
            'lastLocation.lng': { $exists: true, $ne: null },
        }).toArray();

        // Filtrar por radio
        const userLat = ubicacion.coordenadas?.lat;
        const userLng = ubicacion.coordenadas?.lng;

        const barberosEnRadio = barberos.filter(b => {
            const radioKm = b.zonasTrabajo?.radioKm ?? 10;
            if (!userLat || !userLng) return true;
            const distancia = calcularDistanciaKm(
                b.lastLocation.lat, b.lastLocation.lng,
                userLat, userLng
            );
            return distancia <= radioKm;
        });

       
        console.log(`📡 Solicitud enviada a ${barberosEnRadio.length} barberos`);

        res.status(201).json({
            message:          'Solicitud creada, buscando barbero...',
            ServiceRequestId: savedRequest._id,
            estado:           savedRequest.estado,
            barberosNotificados: barberosEnRadio.length,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al crear la solicitud' });
    }
});

router.get('/barbero/:barberId/pendientes', async (req, res) => {
  try {
    const hace60seg = new Date(Date.now() - 60 * 1000);
    const requests = await ServiceRequest.find({
      estado:    'buscando',
      createdAt: { $gte: hace60seg }
    })
    .populate('userId','nombre profileImage')
    .sort({ createdAt: -1 }).limit(5);
    res.json(requests);
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

router.get('/user/:userId/historial', async (req, res) => {
  try {
    const { userId } = req.params;
    const mongoose   = require('mongoose');
    const db         = mongoose.connection.db;

    // Solicitudes Runner — solo estados terminales
    const requests = await ServiceRequest.find({
      userId,
      estado: { $in: ['finalizado', 'cancelado'] } 
       
    }).sort({ createdAt: -1 });
    console.log('Runner encontradas:', requests.length);  

    const runner = await Promise.all(requests.map(async (r) => {
      // Buscar foto del barbero en barberDocuments
      let barberoFoto = null;
      if (r.barberoId) {
        const doc = await db.collection('barberDocuments').findOne(
          { barberId: r.barberoId.toString() },
          { projection: { profileImage: 1 } }
        );
        barberoFoto = doc?.profileImage ?? null;
      }

      return {
        _id:           r._id,
        tipo:          'runner',
        servicios:     r.servicios,
        status:        r.estado,
        barberoNombre: r.barberoNombre ?? 'No asignado',
        barberoId:     r.barberoId,
        barberoFoto,
        fecha:         r.createdAt ? r.createdAt.toISOString().split('T')[0] : null,
        hora:          r.createdAt ? r.createdAt.toISOString().split('T')[1].substring(0, 5) : null,
        costoTotal:    r.costoTotal ?? null,
        calificado:    r.calificado ?? false, 
        createdAt:     r.createdAt,
      };
    }));

    // Reservas agendadas
    const reservas = await db.collection('userReservas').find({
      userId: new mongoose.Types.ObjectId(userId)
    }).sort({ createdAt: -1 }).toArray();
        console.log('Reservas encontradas:', reservas.length); 

    const agendadas = await Promise.all(reservas.map(async (r) => {
      // Foto del barbero desde barberDocuments
      let barberoFoto = null;
      if (r.barberId) {
        const doc = await db.collection('barberDocuments').findOne(
          { barberId: r.barberId.toString() },
          { projection: { profileImage: 1 } }
        );
        barberoFoto = doc?.profileImage ?? null;
      }

      return {
        _id:           r._id,
        tipo:          'agendada',
        servicios:     r.servicios,
        status:        r.status,
        barberoNombre: r.barberoNombre ?? 'Barbero',
        barberoId:     r.barberId,
        barberoFoto,
        fecha:         r.fecha,
        hora:          r.hora,
        costoTotal:    r.costoTotal ?? null,
        calificado:    r.calificado ?? false, 
        createdAt:     r.createdAt,
      };
    }));

    res.json([...runner, ...agendadas].sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
    ));
  } catch (error) {
    console.error('Error historial:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

router.get('/user/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
     

        // Buscamos en la colección usando el campo userId
        // .sort({ createdAt: -1 }) sirve para que los más nuevos aparezcan primero
        const requests = await ServiceRequest.find({ userId: userId }).sort({ createdAt: -1 });

        res.json(requests);
    } catch (error) {
        console.error("❌ Error al obtener servicios:", error);
        res.status(500).json({ error: 'Error al obtener los servicios del usuario' });
    }
});


// GET /api/service-requests/:id/estado
router.get('/:id/estado', async (req, res) => {
  try {
    const request = await ServiceRequest.findById(req.params.id);
     console.log('Estado solicitud:', request?.estado, '| barberoId:', request?.barberoId);
    if (!request) return res.status(404).json({ error: 'No encontrada' });

    let barberoInfo = null;
    if (request.barberoId) {
      const mongoose = require('mongoose');
      const db = mongoose.connection.db;
      const barbero = await db.collection('barberos').findOne(
        { _id: new mongoose.Types.ObjectId(request.barberoId) },
        { projection: { nombre: 1, calificacion: 1, lastLocation: 1 } }
      );
      const docs = await db.collection('barberDocuments').findOne(
        { barberId: request.barberoId.toString() },
        { projection: { profileImage: 1 } }
      );
      barberoInfo = {
        nombre:       barbero?.nombre ?? 'Barbero',
        calificacion: barbero?.calificacion ?? { promedio: 0, totalReseñas: 0 },
        lastLocation: barbero?.lastLocation ?? null,
        profileImage: docs?.profileImage ?? null,
      };
    }

    res.json({
      estado:    request.estado,
      barberoId: request.barberoId,
      barberoInfo,
      costoTotal: request.costoTotal ?? 0,
      desglosePrecio: request.desglosePrecio ?? null, 
    });
  } catch (e) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Helper: calcular distancia en km entre dos coordenadas (Haversine)
function calcularDistanciaKm(lat1, lng1, lat2, lng2) {
    const R    = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a    = Math.sin(dLat/2) * Math.sin(dLat/2) +
                 Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
                 Math.sin(dLng/2) * Math.sin(dLng/2);
    const c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
}


router.get('/:id', async (req, res) => {
  try {
    const request = await ServiceRequest.findById(req.params.id);
    if (!request) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }
    res.json(request);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});




router.put('/:id/aceptar', async (req, res) => {
  try {
    const { barberId, barberName, distanciaKm } = req.body; // ← agrega distanciaKm
    const request = await ServiceRequest.findByIdAndUpdate(
      req.params.id,
      {
        estado:        'barbero_asignado',
        barberoId:     barberId,
        barberoNombre: barberName,
        distanciaKm:   distanciaKm ?? 1, // ← guarda la distancia
      },
      { new: true }
    );
    if (!request) return res.status(404).json({ error: 'No encontrada' });
    res.json({ success: true, data: request });
  } catch (e) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});


// PUT /api/service-requests/:id/llegar
router.put('/:id/llegar', async (req, res) => {
  try {
    const request = await ServiceRequest.findByIdAndUpdate(
      req.params.id,
      { estado: 'en_servicio', horaLlegada: new Date() },
      { new: true }
    );
    if (!request) return res.status(404).json({ error: 'No encontrada' });
    res.json({ success: true, data: request });
  } catch (e) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

router.put('/:id/finalizar', async (req, res) => {
  try {
    const request = await ServiceRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'No encontrada' });

    // Obtener datos del barbero para calcular nivel
    const barbero = await Barber.findById(request.barberoId);
    const promedio      = barbero?.calificacion?.promedio     ?? 0;
    const totalResenias = barbero?.calificacion?.totalReseñas ?? 0;

    // Distancia — usar la guardada en la solicitud
    const distanciaKm = request.distanciaKm ?? 1;

    // Calcular precio real
    const precio = calcularPrecio(
      request.servicios,
      distanciaKm,
      promedio,
      totalResenias,
    );

    // Guardar en BD
    const updated = await ServiceRequest.findByIdAndUpdate(
      req.params.id,
      {
        estado:       'finalizado',
        horaFin:      new Date(),
        costoTotal:   precio.total,
        costoEstimado: precio.total,
        desglosePrecio: precio, // guarda el detalle completo
      },
      { new: true }
    );

    res.json({ success: true, data: updated, precio });
  } catch (e) {
    console.error('Error finalizando:', e.message);
    res.status(500).json({ error: 'Error del servidor' });
  }
});



module.exports = router;