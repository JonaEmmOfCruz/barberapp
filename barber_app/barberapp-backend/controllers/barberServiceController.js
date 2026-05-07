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
    const { filtro } = req.query;

    let fechaFiltro = new Date();
    if (filtro === 'Hoy')   fechaFiltro.setHours(0, 0, 0, 0);
    if (filtro === 'Semana') fechaFiltro.setDate(fechaFiltro.getDate() - 7);
    if (filtro === 'Mes')    fechaFiltro.setMonth(fechaFiltro.getMonth() - 1);

    const barberObjectId = new mongoose.Types.ObjectId(barberId);

    // ── Ganancias de Runner (ServiceCard) ───────────────────────────
    const statsRunner = await ServiceCard.aggregate([
      { $match: { barberId: barberObjectId, fecha: { $gte: fechaFiltro }, status: 'finalizado' } },
      { $group: { _id: null, total: { $sum: '$ganancia' } } }
    ]);

    // ── Ganancias de Citas (Appointment) ────────────────────────────
    const statsCitas = await Appointment.aggregate([
      { $match: { barberId: barberObjectId, createdAt: { $gte: fechaFiltro }, status: 'finalizada' } },
      { $group: { _id: null, total: { $sum: '$precioTotal' } } }
    ]);

    const gananciaRunner = statsRunner[0]?.total ?? 0;
    const gananciaCitas  = statsCitas[0]?.total  ?? 0;
    const gananciaTotal  = gananciaRunner + gananciaCitas;

    // ── Lista unificada ordenada por fecha ───────────────────────────
    const listaRunner = await ServiceCard.find({
      barberId: barberObjectId,
      fecha: { $gte: fechaFiltro },
      status: 'finalizado'
    }).sort({ fecha: -1 }).lean();

    const listaCitas = await Appointment.find({
      barberId: barberObjectId,
      createdAt: { $gte: fechaFiltro },
      status: 'finalizada'
    }).sort({ createdAt: -1 }).lean();

    // ── Reservas agendadas completadas (userReservas) ─────────────
const db = require('mongoose').connection.db;
const listaReservas = await db.collection('userReservas').find({
    barberId: barberObjectId,
    status:   'completada',
    createdAt: { $gte: fechaFiltro }
}).sort({ createdAt: -1 }).toArray();

// Enriquecer con nombre del cliente
const listaReservasNormalizada = await Promise.all(
    listaReservas.map(async (r) => {
        const cliente = await db.collection('users').findOne(
            { _id: r.userId },
            { projection: { nombre: 1 } }
        );
        return {
            _id:           r._id,
            tipo:          'Cita',
            servicios:     Array.isArray(r.servicios) ? r.servicios.join(', ') : 'Cita agendada',
            ganancia:      0,
            duracionMin:   0,
            fecha:         r.createdAt ?? new Date(),
            clienteNombre: cliente?.nombre ?? 'Cliente',
        };
    })
);

    // Normalizamos los campos para que Flutter reciba estructura uniforme
    const historialNormalizado = [
      ...listaRunner.map(s => ({
        _id:            s._id,
        tipo:           'Runner',                  // badge en la card
        servicios:      s.servicios,
        ganancia:       s.ganancia,
        duracionMin:    s.duracionTotalMinutos,
        fecha:          s.fecha,
        clienteNombre:  null                       // Runner no siempre tiene nombre
      })),
      ...listaCitas.map(a => ({
        _id:            a._id,
        tipo:           'Cita',                    // badge en la card
        servicios:      'Cita agendada',
        ganancia:       a.precioTotal ?? 0,
        duracionMin:    a.horaFin && a.horaLlegada
                          ? Math.round((new Date(a.horaFin) - new Date(a.horaLlegada)) / 60000)
                          : 0,
        fecha:          a.createdAt,
        clienteNombre:  a.clienteNombre ?? null
      })),
      ...listaReservasNormalizada
    ].sort((a, b) => new Date(b.fecha) - new Date(a.fecha)); // más reciente primero

    res.status(200).json({
      gananciaTotal,
      desglose: { runner: gananciaRunner, citas: gananciaCitas },
      servicios: historialNormalizado
    });

  } catch (error) {
    res.status(500).json({ message: 'Error en el servidor', error });
  }
};