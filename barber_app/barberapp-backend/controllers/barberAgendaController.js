const AgendaSlot  = require('../models/barberAgendaSlot');
const Barber      = require('../models/barberos');
const BarberJornada = require('../models/barberJornada');
const axios       = require('axios');

const INTERVALO_SLOT_MIN   = 30;
const BUFFER_SEGURIDAD_MIN = 10;

// ─────────────────────────────────────────────────────────────────────
//  abrirJornada
//  POST /api/disponibilidad/:barberId/jornada
//
//  El barbero define su ventana de trabajo para un día.
//  El sistema genera los slots automáticamente.
//
//  Body: {
//    fecha: "YYYY-MM-DD",
//    inicioHora: "09:00",
//    finHora: "14:00",
//    descanso: {           ← opcional
//      inicioHora: "12:00",
//      finHora: "13:00"
//    }
//  }
// ─────────────────────────────────────────────────────────────────────
exports.abrirJornada = async (req, res) => {
  try {
    const { barberId } = req.params;
    const { fecha, inicioHora, finHora, descanso } = req.body;

    if (!fecha || !inicioHora || !finHora) {
      return res.status(400).json({ success: false, msg: 'Faltan datos: fecha, inicioHora, finHora' });
    }

    const inicioMin = _horaAMinutos(inicioHora);
    const finMin    = _horaAMinutos(finHora);

    if (inicioMin >= finMin) {
      return res.status(400).json({ success: false, msg: 'La hora de inicio debe ser menor a la de fin' });
    }

    // Descanso opcional
    let descansoData = { activo: false, inicioMin: null, finMin: null, inicioHora: null, finHora: null };
    if (descanso && descanso.inicioHora && descanso.finHora) {
      const dInicioMin = _horaAMinutos(descanso.inicioHora);
      const dFinMin    = _horaAMinutos(descanso.finHora);
      if (dInicioMin >= inicioMin && dFinMin <= finMin && dInicioMin < dFinMin) {
        descansoData = {
          activo:     true,
          inicioMin:  dInicioMin,
          finMin:     dFinMin,
          inicioHora: descanso.inicioHora,
          finHora:    descanso.finHora,
        };
      }
    }

    // Si ya existe una jornada para ese día, la eliminamos con sus slots
    const jornadaExistente = await BarberJornada.findOne({ barberId, fecha });
    if (jornadaExistente) {
      await AgendaSlot.deleteMany({ jornadaId: jornadaExistente._id });
      await BarberJornada.deleteOne({ _id: jornadaExistente._id });
    }

    // Creamos la jornada
    const jornada = await BarberJornada.create({
      barberId,
      fecha,
      inicioMin,
      finMin,
      inicioHora,
      finHora,
      descanso: descansoData,
      status: 'abierta'
    });

    // Generamos los slots automáticamente
    const slots = _generarSlots(jornada);
    if (slots.length > 0) {
      await AgendaSlot.insertMany(slots.map(s => ({ ...s, barberId, jornadaId: jornada._id })));
    }

    // Actualizamos totalSlotsGenerados
    await BarberJornada.findByIdAndUpdate(jornada._id, {
      totalSlotsGenerados: slots.length
    });

    // Recalculamos workMode del barbero
    const barber = await Barber.findById(barberId);
    const workMode = Barber.calcularWorkMode(barber.isAvailable, slots.length > 0);
    await Barber.findByIdAndUpdate(barberId, { $set: { workMode } });

    res.status(201).json({
      success: true,
      msg: `Jornada abierta. ${slots.length} slots generados.`,
      jornada: {
        id:          jornada._id,
        fecha,
        inicioHora,
        finHora,
        descanso:    descansoData.activo ? descansoData : null,
        totalSlots:  slots.length,
      },
      workMode,
      slots: slots.map(s => ({ hora: s.hora, horaMinutos: s.horaMinutos, status: s.status }))
    });

  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ success: false, msg: 'Ya existe una jornada para ese día. Ciérrala primero.' });
    }
    console.error('Error abrirJornada:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  getJornadasSemana
//  GET /api/disponibilidad/:barberId/jornadas?fechaInicio=YYYY-MM-DD
//
//  Devuelve las jornadas de los próximos 7 días para mostrar
//  en la pantalla de agenda semanal.
// ─────────────────────────────────────────────────────────────────────
exports.getJornadasSemana = async (req, res) => {
  try {
    const { barberId } = req.params;
    const fechaInicio = req.query.fechaInicio ?? _fechaHoy();

    // Calculamos los próximos 7 días
    const fechas = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(fechaInicio);
      d.setDate(d.getDate() + i);
      fechas.push(d.toISOString().split('T')[0]);
    }

    const jornadas = await BarberJornada.find({
      barberId,
      fecha: { $in: fechas },
      status: 'abierta'
    });

    // Para cada fecha, agregamos si tiene jornada o no
    const resultado = fechas.map(fecha => {
      const jornada = jornadas.find(j => j.fecha === fecha);
      return {
        fecha,
        diaSemana:   _nombreDia(fecha),
        tieneJornada: !!jornada,
        jornada: jornada ? {
          id:         jornada._id,
          inicioHora: jornada.inicioHora,
          finHora:    jornada.finHora,
          descanso:   jornada.descanso?.activo ? jornada.descanso : null,
          totalSlots: jornada.totalSlotsGenerados,
        } : null
      };
    });

    res.status(200).json({ success: true, semana: resultado });

  } catch (error) {
    console.error('Error getJornadasSemana:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  getSlotsDelDia
//  GET /api/disponibilidad/:barberId/slots?fecha=YYYY-MM-DD
// ─────────────────────────────────────────────────────────────────────
exports.getSlotsDelDia = async (req, res) => {
  try {
    const { barberId } = req.params;
    const fecha = req.query.fecha ?? _fechaHoy();

    const slots = await AgendaSlot.find({ barberId, fecha })
      .sort({ horaMinutos: 1 });

    const jornada = await BarberJornada.findOne({ barberId, fecha, status: 'abierta' });

    res.status(200).json({
      success: true,
      fecha,
      tieneJornada: !!jornada,
      jornada: jornada ? {
        inicioHora: jornada.inicioHora,
        finHora:    jornada.finHora,
        descanso:   jornada.descanso?.activo ? jornada.descanso : null,
      } : null,
      slots: slots.map(s => ({
        id:                 s._id,
        hora:               s.hora,
        horaMinutos:        s.horaMinutos,
        status:             s.status,
        duracionEstimadaMin: s.duracionEstimadaMin,
        clientId:           s.clientId,
      }))
    });

  } catch (error) {
    console.error('Error getSlotsDelDia:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  cerrarJornada
//  DELETE /api/disponibilidad/:barberId/jornada/:jornadaId
//
//  El barbero cierra su jornada (cancela los slots disponibles).
//  Los slots ocupados (con citas) NO se eliminan.
// ─────────────────────────────────────────────────────────────────────
exports.cerrarJornada = async (req, res) => {
  try {
    const { barberId, jornadaId } = req.params;

    const jornada = await BarberJornada.findOne({ _id: jornadaId, barberId });
    if (!jornada) {
      return res.status(404).json({ success: false, msg: 'Jornada no encontrada' });
    }

    // Verificamos si hay citas agendadas
    const citasAgendadas = await AgendaSlot.countDocuments({
      jornadaId,
      status: 'ocupado'
    });

    if (citasAgendadas > 0) {
      return res.status(400).json({
        success: false,
        msg: `No puedes cerrar la jornada, tienes ${citasAgendadas} cita(s) agendada(s).`
      });
    }

    // Eliminamos solo los slots disponibles y de descanso
    await AgendaSlot.deleteMany({ jornadaId, status: { $in: ['disponible', 'descanso', 'bloqueado'] } });
    await BarberJornada.findByIdAndUpdate(jornadaId, { status: 'cancelada' });

    // Recalculamos workMode
    const barber = await Barber.findById(barberId);
    const slotsRestantes = await AgendaSlot.countDocuments({ barberId, fecha: jornada.fecha, status: 'disponible' });
    const workMode = Barber.calcularWorkMode(barber.isAvailable, slotsRestantes > 0);
    await Barber.findByIdAndUpdate(barberId, { $set: { workMode } });

    res.status(200).json({ success: true, msg: 'Jornada cerrada.', workMode });

  } catch (error) {
    console.error('Error cerrarJornada:', error);
    res.status(500).json({ success: false, msg: 'Error del servidor' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  verificarConflictoRunner  (modo híbrido)
//  POST /api/disponibilidad/:barberId/verificar-runner
// ─────────────────────────────────────────────────────────────────────
exports.verificarConflictoRunner = async (req, res) => {
  try {
    const { barberId } = req.params;
    const { tiempoServicioMin, latCliente, lngCliente, latBarbero, lngBarbero } = req.body;

    const proxima = await _getProximaCita(barberId);

    if (!proxima) {
      return res.status(200).json({ success: true, puedeAceptar: true, motivo: null });
    }

    const tiempoTraslado = await _getTiempoTrasladoGoogle(latBarbero, lngBarbero, latCliente, lngCliente);
    const ahoraMin       = _minutosDesdeMedianoche(new Date());
    const tiempoNecesario = tiempoTraslado + tiempoServicioMin + BUFFER_SEGURIDAD_MIN;
    const horaLimite      = proxima.horaMinutos - tiempoNecesario;
    const puedeAceptar    = ahoraMin <= horaLimite;

    res.status(200).json({
      success: true,
      puedeAceptar,
      detalle: {
        proximaCita:       proxima.hora,
        tiempoTrasladoMin: tiempoTraslado,
        tiempoServicioMin,
        bufferMin:         BUFFER_SEGURIDAD_MIN,
        tiempoNecesario,
        minutosDisponibles: Math.max(0, horaLimite - ahoraMin),
        motivo: puedeAceptar ? null : `No hay tiempo suficiente antes de tu cita de las ${proxima.hora}`
      }
    });

  } catch (error) {
    console.error('Error verificarConflictoRunner:', error);
    res.status(200).json({ success: true, puedeAceptar: true, motivo: 'Error en verificación' });
  }
};

// ─────────────────────────────────────────────────────────────────────
//  HELPERS PRIVADOS
// ─────────────────────────────────────────────────────────────────────

// Genera la lista de slots a partir de una jornada
function _generarSlots(jornada) {
  const slots = [];
  const { inicioMin, finMin, descanso } = jornada;

  for (let min = inicioMin; min < finMin; min += INTERVALO_SLOT_MIN) {
    // Verificamos si cae dentro del descanso
    if (descanso?.activo && min >= descanso.inicioMin && min < descanso.finMin) {
      slots.push({
        fecha:       jornada.fecha,
        hora:        _minutosAHora(min),
        horaMinutos: min,
        status:      'descanso'
      });
      continue;
    }

    slots.push({
      fecha:       jornada.fecha,
      hora:        _minutosAHora(min),
      horaMinutos: min,
      status:      'disponible'
    });
  }

  return slots;
}

async function _getProximaCita(barberId) {
  const hoy      = _fechaHoy();
  const ahoraMin = _minutosDesdeMedianoche(new Date());

  return await AgendaSlot.findOne({
    barberId,
    fecha:        hoy,
    status:       'ocupado',
    horaMinutos:  { $gt: ahoraMin }
  }).sort({ horaMinutos: 1 });
}

async function _getTiempoTrasladoGoogle(latOrigen, lngOrigen, latDestino, lngDestino) {
  try {
    const { data } = await axios.get('https://maps.googleapis.com/maps/api/directions/json', {
      params: {
        origin:         `${latOrigen},${lngOrigen}`,
        destination:    `${latDestino},${lngDestino}`,
        mode:           'driving',
        departure_time: 'now',
        key:            process.env.GOOGLE_MAPS_API_KEY
      }
    });

    if (data.status === 'OK' && data.routes.length > 0) {
      const leg = data.routes[0].legs[0];
      const seg = leg.duration_in_traffic?.value ?? leg.duration.value;
      return Math.ceil(seg / 60);
    }
    return 20;
  } catch {
    return 20;
  }
}

function _horaAMinutos(hora) {
  const [h, m] = hora.split(':').map(Number);
  return h * 60 + m;
}

function _minutosAHora(minutos) {
  const h = Math.floor(minutos / 60).toString().padStart(2, '0');
  const m = (minutos % 60).toString().padStart(2, '0');
  return `${h}:${m}`;
}

function _fechaHoy() {
  return new Date().toISOString().split('T')[0];
}

function _minutosDesdeMedianoche(date) {
  return date.getHours() * 60 + date.getMinutes();
}

function _nombreDia(fecha) {
  const dias = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];
  return dias[new Date(fecha + 'T12:00:00').getDay()];
}