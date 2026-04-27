const Barber = require('../models/barberos');
const AgendaSlot = require('../models/barberAgendaSlot');

// ─────────────────────────────────────────────────────────────────────
//  toggleDisponibilidad
//  PUT /api/disponibilidad/:barberId/toggle
//
//  Cambia isAvailable y recalcula workMode automáticamente.
//  No toca los slots de agenda (eso es independiente).
// ─────────────────────────────────────────────────────────────────────
exports.toggleDisponibilidad = async (req, res) => {
  try {
    const { barberId } = req.params;
    const { isAvailable, lat, lng } = req.body;

    // Verificamos si el barbero tiene slots activos HOY
    const hoy = _fechaHoy();
    const slotsActivos = await AgendaSlot.countDocuments({
      barberId,
      fecha: hoy,
      status: 'disponible'
    });
    const tieneSlotsActivos = slotsActivos > 0;

    // Calculamos el workMode con la lógica centralizada del model
    const workMode = Barber.calcularWorkMode(isAvailable, tieneSlotsActivos);

    // Armamos el update — también guardamos última ubicación si viene
    const update = { isAvailable, workMode };
    if (lat !== undefined && lng !== undefined) {
      update.lastLocation = { lat, lng };
    }

    const barber = await Barber.findByIdAndUpdate(
      barberId,
      { $set: update },
      { new: true, select: 'nombre isAvailable isWorking workMode lastLocation metricas agendaHoy' }
    );

    if (!barber) {
      return res.status(404).json({ success: false, msg: 'Barbero no encontrado' });
    }

    res.status(200).json({
      success: true,
      isAvailable: barber.isAvailable,
      workMode: barber.workMode,
      msg: _mensajeWorkMode(workMode)
    });

  } catch (error) {
    console.error('Error en toggleDisponibilidad:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  getEstado
//  GET /api/disponibilidad/:barberId/estado
//
//  Devuelve el estado completo del barbero al iniciar la app.
//  Flutter llama esto en initState() del Home.
// ─────────────────────────────────────────────────────────────────────
exports.getEstado = async (req, res) => {
  try {
    const { barberId } = req.params;

    const barber = await Barber.findById(barberId)
      .select('nombre isAvailable isWorking workMode lastLocation metricas agendaHoy');

    if (!barber) {
      return res.status(404).json({ success: false, msg: 'Barbero no encontrado' });
    }

    // Traemos también los slots activos de hoy para que Flutter los muestre
    const hoy = _fechaHoy();
    const slotsHoy = await AgendaSlot.find({
      barberId,
      fecha: hoy
    }).sort({ horaMinutos: 1 });

    res.status(200).json({
      success: true,
      barberId: barber._id,
      nombre: barber.nombre,
      isAvailable: barber.isAvailable,
      isWorking: barber.isWorking,
      workMode: barber.workMode,
      metricas: {
        totalServicios: barber.metricas?.totalServicios ?? 0,
        promedioServicioMin: barber.metricas?.promedioServicioMin ?? null,
        esFase1: (barber.metricas?.totalServicios ?? 0) < 10
      },
      slotsHoy: slotsHoy.map(s => ({
        id: s._id,
        hora: s.hora,
        status: s.status,
        duracionEstimadaMin: s.duracionEstimadaMin,
        clientId: s.clientId
      }))
    });

  } catch (error) {
    console.error('Error en getEstado:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  actualizarUbicacion
//  PUT /api/disponibilidad/:barberId/ubicacion
//
//  El app manda la ubicación en tiempo real cuando el barbero
//  está disponible o en modo runner.
// ─────────────────────────────────────────────────────────────────────
exports.actualizarUbicacion = async (req, res) => {
  try {
    const { barberId } = req.params;
    const { lat, lng } = req.body;

    if (!lat || !lng) {
      return res.status(400).json({ success: false, msg: 'Faltan coordenadas' });
    }

    await Barber.findByIdAndUpdate(barberId, {
      $set: { lastLocation: { lat, lng } }
    });

    res.status(200).json({ success: true });

  } catch (error) {
    console.error('Error actualizarUbicacion:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  actualizarMetricas  (llamado internamente al finalizar servicio)
//  No es un endpoint HTTP — lo llama finalizarServicio del controller
//  de servicios al guardar una ServiceCard.
// ─────────────────────────────────────────────────────────────────────
exports.actualizarMetricas = async (barberId, tipoServicio, duracionRealMin) => {
  try {
    const barber = await Barber.findById(barberId);
    if (!barber) return;

    // Inicializamos métricas si no existen
    if (!barber.metricas) {
      barber.metricas = { totalServicios: 0, promedioServicioMin: null, porTipo: new Map() };
    }

    const metricas = barber.metricas;
    const total = (metricas.totalServicios ?? 0) + 1;

    // Recalculamos el promedio general con media móvil
    const promedioAnterior = metricas.promedioServicioMin ?? duracionRealMin;
    const nuevoPromedio = Math.round(((promedioAnterior * (total - 1)) + duracionRealMin) / total);

    // Actualizamos el breakdown por tipo de servicio
    const porTipo = metricas.porTipo ?? new Map();
    const datoTipo = porTipo.get(tipoServicio) ?? { cantidad: 0, promedioMin: null };
    const nuevaCantidad = datoTipo.cantidad + 1;
    const promedioTipoAnterior = datoTipo.promedioMin ?? duracionRealMin;
    const nuevoPromedioTipo = Math.round(
      ((promedioTipoAnterior * (nuevaCantidad - 1)) + duracionRealMin) / nuevaCantidad
    );
    porTipo.set(tipoServicio, { cantidad: nuevaCantidad, promedioMin: nuevoPromedioTipo });

    await Barber.findByIdAndUpdate(barberId, {
      $set: {
        'metricas.totalServicios':      total,
        'metricas.promedioServicioMin': nuevoPromedio,
        'metricas.porTipo':             porTipo
      }
    });

    console.log(`[Métricas] Barbero ${barberId} → Total: ${total}, Promedio: ${nuevoPromedio} min`);

  } catch (error) {
    console.error('Error actualizarMetricas:', error);
    // No lanzamos el error para que no interrumpa el flujo de finalizar servicio
  }
};

// ─────────────────────────────────────────────────────────────────────
//  HELPERS PRIVADOS
// ─────────────────────────────────────────────────────────────────────
function _fechaHoy() {
  return new Date().toISOString().split('T')[0]; // "YYYY-MM-DD"
}

function _mensajeWorkMode(workMode) {
  const msgs = {
    'offline':  'No disponible. No recibirás solicitudes.',
    'runner':   'Modo Runner activado. Recibirás solicitudes al instante.',
    'agenda':   'Modo Agenda activado. Los clientes pueden agendar tus slots.',
    'hibrido':  'Modo Híbrido activado. Runner + Agenda simultáneos.'
  };
  return msgs[workMode] ?? '';
}