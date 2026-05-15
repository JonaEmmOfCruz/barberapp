const ServiceCard = require('../models/barberCardService');

const mongoose = require('mongoose');
const { actualizarMetricas } = require('./barberdisponibilidadController');

// ─────────────────────────────────────────────────────────────────────
//  aceptarServicio  (Runner)
// ─────────────────────────────────────────────────────────────────────
exports.aceptarServicio = async (req, res) => {
  try {
    const { barberId, clientId, servicios, gananciaEstimada, tipo } = req.body;

    const nuevaCard = new ServiceCard({
      barberId,
      clientId,
      servicios,
      ganancia: gananciaEstimada,
      tipo: tipo ?? 'Runner',
      status: 'pendiente'
    });

    await nuevaCard.save();
    res.status(201).json(nuevaCard);
  } catch (error) {
    res.status(500).json({ message: 'Error al crear servicio', error });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  iniciarViaje  — Botón "IR"
// ─────────────────────────────────────────────────────────────────────
exports.iniciarViaje = async (req, res) => {
  try {
    const { id } = req.params;
    const servicio = await ServiceCard.findByIdAndUpdate(id, {
      status: 'en_camino',
      horaSalida: new Date()
    }, { new: true });
    res.status(200).json(servicio);
  } catch (error) {
    res.status(500).json({ message: 'Error al iniciar viaje', error });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  registrarLlegada — GPS
// ─────────────────────────────────────────────────────────────────────
exports.registrarLlegada = async (req, res) => {
  try {
    const { id } = req.params;
    const servicio = await ServiceCard.findByIdAndUpdate(id, {
      status: 'en_proceso',
      horaLlegada: new Date(),
      horaInicio: new Date()
    }, { new: true });
    res.status(200).json(servicio);
  } catch (error) {
    res.status(500).json({ message: 'Error al registrar llegada', error });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  finalizarServicio — Calcula duración + actualiza métricas del barbero
// ─────────────────────────────────────────────────────────────────────
exports.finalizarServicio = async (req, res) => {
  try {
    const { id } = req.params;
    const servicio = await ServiceCard.findById(id);
    if (!servicio) return res.status(404).json({ message: 'No encontrado' });

    servicio.horaFin = new Date();
    servicio.status  = 'finalizado';
    await servicio.save(); // pre('save') calcula duracionTotalMinutos

    // ── Actualizar métricas del barbero con el tiempo real ──────────
    if (servicio.duracionTotalMinutos > 0) {
      await actualizarMetricas(
        servicio.barberId,
        servicio.servicios,        // tipo de servicio como string
        servicio.duracionTotalMinutos
      );
    }

    res.status(200).json(servicio);
  } catch (error) {
    res.status(500).json({ message: 'Error al finalizar', error });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  getStats — Historial unificado (Runner + Citas)
//
//  Usa $unionWith para mezclar ServiceCards (Runner) con
//  Appointments (Citas) en una sola respuesta ordenada por fecha.
//  Flutter recibe todo junto con el campo `tipo` para el badge.
// ─────────────────────────────────────────────────────────────────────
exports.getStats = async (req, res) => {
  try {
    const { barberId } = req.params;
    const { filtro }   = req.query;
    const mongoose     = require('mongoose');
    const db           = mongoose.connection.db;

    let fechaFiltro = new Date();
    if (filtro === 'Hoy')    fechaFiltro.setHours(0, 0, 0, 0);
    if (filtro === 'Semana') fechaFiltro.setDate(fechaFiltro.getDate() - 7);
    if (filtro === 'Mes')    fechaFiltro.setMonth(fechaFiltro.getMonth() - 1);

    const ServiceRequest = require('../models/userServiceRequest');
    const barberObjectId = new mongoose.Types.ObjectId(barberId);

    // ── Runner (servicerequests) ──────────────────────────────────
    const runnerDocs = await ServiceRequest.find({
      barberoId: barberId,
      estado:    'finalizado',
      createdAt: { $gte: fechaFiltro }
    }).sort({ createdAt: -1 }).lean();

    // Enriquecer con nombre del cliente
    const listaRunner = await Promise.all(runnerDocs.map(async (r) => {
      const cliente = await db.collection('users').findOne(
        { _id: new mongoose.Types.ObjectId(r.userId) },
        { projection: { nombre: 1, profileImage: 1 } }
      );
      return {
        _id:           r._id,
        tipo:          'Runner',
        servicios:     Array.isArray(r.servicios) ? r.servicios.join(', ') : 'Servicio runner',
        ganancia:      r.costoTotal ?? 0,
        duracionMin:   r.horaFin && r.horaLlegada
                         ? Math.round((new Date(r.horaFin) - new Date(r.horaLlegada)) / 60000)
                         : 0,
        fecha:         r.createdAt,
        clienteNombre: cliente?.nombre ?? 'Cliente',
        clienteFoto:   cliente?.profileImage ?? null,
      };
    }));

    // ── Citas agendadas (userReservas) ────────────────────────────
    const reservasDocs = await db.collection('userReservas').find({
      barberId: barberObjectId,
      status:   'completada',
      createdAt: { $gte: fechaFiltro }
    }).sort({ createdAt: -1 }).toArray();

    const listaCitas = await Promise.all(reservasDocs.map(async (r) => {
      const cliente = await db.collection('users').findOne(
        { _id: r.userId },
        { projection: { nombre: 1, profileImage: 1 } }
      );
      return {
        _id:           r._id,
        tipo:          'Cita',
        servicios:     Array.isArray(r.servicios) ? r.servicios.join(', ') : 'Cita agendada',
        ganancia:      r.precioTotal ?? 0,
        duracionMin:   0,
        fecha:         r.createdAt ?? new Date(),
        clienteNombre: cliente?.nombre ?? 'Cliente',
        clienteFoto:   cliente?.profileImage ?? null,
      };
    }));

    // ── Totales ───────────────────────────────────────────────────
    const gananciaRunner = listaRunner.reduce((sum, s) => sum + s.ganancia, 0);
    const gananciaCitas  = listaCitas.reduce((sum, s) => sum + s.ganancia, 0);
    const gananciaTotal  = gananciaRunner + gananciaCitas;

    // ── Lista unificada ───────────────────────────────────────────
    const historial = [...listaRunner, ...listaCitas]
      .sort((a, b) => new Date(b.fecha) - new Date(a.fecha));

    res.status(200).json({
      gananciaTotal,
      desglose: { runner: gananciaRunner, citas: gananciaCitas },
      servicios: historial
    });

  } catch (error) {
    console.error('Error getStats:', error.message);
    res.status(500).json({ message: 'Error en el servidor', error: error.message });
  }
};