const express = require('express')
const router = express.Router()
const ServiceRequest = require('../models/userServiceRequest')

router.post('/', async (req, res) => {
    try {
        const {userId, tipo, servicios, ubicacion} = req.body;

        if (!userId || !tipo || !servicios || servicios.length === 0){
            return res.status(400).json({error: 'Falta datos obligatorios'})
        }

        const newRequest = new ServiceRequest({
            userId,
            tipoServicioGeneral: tipo,
            servicios: servicios,
            ubicacion: {
                direccion: ubicacion.direccion,
                coordenadas: ubicacion.coordenadas
            },
            estado: 'buscando'
        });

        const savedRequest = await newRequest.save();

        // Aquí podrías iniciar la lógica de búsqueda de barberos cercanos
        // (por ejemplo, emitir un evento con Socket.io o llamar a un servicio)

        res.status(201).json({
            message: 'Solicitud creada, buscando barbero...',
            ServiceRequestId: savedRequest._id,
            estado: savedRequest.estado
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({error: 'Error al crear la solicitud'});
    }
});

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

router.get('/user/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        console.log("🔍 Buscando servicios para el usuario ID:", userId);

        // Buscamos en la colección usando el campo userId
        // .sort({ createdAt: -1 }) sirve para que los más nuevos aparezcan primero
        const requests = await ServiceRequest.find({ userId: userId }).sort({ createdAt: -1 });

        console.log(`✅ Se encontraron ${requests.length} solicitudes.`);
        res.json(requests);
    } catch (error) {
        console.error("❌ Error al obtener servicios:", error);
        res.status(500).json({ error: 'Error al obtener los servicios del usuario' });
    }
});
router.get('/user/:userId/historial', async (req, res) => {
    try {
        const { userId } = req.params;
        const mongoose   = require('mongoose');
        const db         = mongoose.connection.db;

        // Solicitudes Runner
        const requests = await ServiceRequest.find({ userId }).sort({ createdAt: -1 });
        const runner = requests.map(r => ({
            _id:          r._id,
            tipo:         'runner',
            servicios:    r.servicios,
            status:       r.estado,
            barberoNombre: r.barberoNombre ?? 'No asignado',
            createdAt:    r.fechaCreacion,
        }));

        // Reservas agendadas
        const reservas = await db.collection('userReservas').find({
            userId: new mongoose.Types.ObjectId(userId)
        }).sort({ createdAt: -1 }).toArray();

        const agendadas = await Promise.all(reservas.map(async (r) => {
            const barbero = await db.collection('barberos').findOne(
                { _id: r.barberId },
                { projection: { nombre: 1 } }
            );
            return {
                _id:           r._id,
                tipo:          'agendada',
                servicios:     r.servicios,
                status:        r.status,
                barberoNombre: barbero?.nombre ?? 'Barbero',
                fecha:         r.fecha,
                hora:          r.hora,
                createdAt:     r.createdAt,
            };
        }));

        // Combinar y ordenar por fecha
        const historial = [...runner, ...agendadas].sort(
            (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
        );

        res.json(historial);
    } catch (error) {
        res.status(500).json({ error: 'Error al obtener historial' });
    }
});

module.exports = router;