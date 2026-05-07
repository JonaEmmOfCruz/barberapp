const express = require('express');
const router = express.Router();
const disponibilidadController = require('../controllers/barberDisponibilidadController');
const agendaController = require('../controllers/barberAgendaController');

// ═══════════════════════════════════════════════
//  DISPONIBILIDAD (Toggle + Estado)
// ═══════════════════════════════════════════════

router.get('/:barberId/estado', disponibilidadController.getEstado);
router.put('/:barberId/toggle', disponibilidadController.toggleDisponibilidad);
router.put('/:barberId/ubicacion', disponibilidadController.actualizarUbicacion);

// ═══════════════════════════════════════════════
//  AGENDA (Slots del día)
// ═══════════════════════════════════════════════

router.get('/:barberId/slots', agendaController.getSlotsDelDia);
router.post('/:barberId/verificar-runner', agendaController.verificarConflictoRunner);
router.post('/:barberId/jornada', agendaController.abrirJornada);
router.get('/:barberId/jornadas', agendaController.getJornadasSemana);
router.delete('/:barberId/jornada/:jornadaId', agendaController.cerrarJornada);

// ═══════════════════════════════════════════════
//  HORARIO BASE (Nuevo sistema sin jornada diaria)
// ═══════════════════════════════════════════════
const BarberDisponibilidad = require('../models/barberDisponibilidad');
const AgendaSlot = require('../models/barberAgendaSlot');
const mongoose = require('mongoose');

// GET /api/disponibilidad/:barberId/horario
router.get('/:barberId/horario', async (req, res) => {
  try {
    const disp = await BarberDisponibilidad.findOne({ barberId: req.params.barberId });
    res.json(disp ?? {});
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// POST /api/disponibilidad/:barberId/horario
router.post('/:barberId/horario', async (req, res) => {
  try {
    const { diasDisponibles, duracionSlotMin, duracionPorServicio } = req.body;
    const disp = await BarberDisponibilidad.findOneAndUpdate(
      { barberId: req.params.barberId },
      {
        diasDisponibles,
        duracionSlotMin: duracionSlotMin ?? 30,
        duracionPorServicio: duracionPorServicio ?? [],
      },
      { upsert: true, new: true }
    );
    res.json({ success: true, data: disp });
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// POST /api/disponibilidad/:barberId/bloquear
router.post('/:barberId/bloquear', async (req, res) => {
  try {
    const { fecha, motivo } = req.body;
    const disp = await BarberDisponibilidad.findOneAndUpdate(
      { barberId: req.params.barberId },
      { $addToSet: { diasBloqueados: { fecha, motivo: motivo ?? '' } } },
      { upsert: true, new: true }
    );
    res.json({ success: true, data: disp });
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// DELETE /api/disponibilidad/:barberId/bloquear
router.delete('/:barberId/bloquear', async (req, res) => {
  try {
    const { fecha } = req.body;
    await BarberDisponibilidad.findOneAndUpdate(
      { barberId: req.params.barberId },
      { $pull: { diasBloqueados: { fecha } } }
    );
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// GET /api/disponibilidad/:barberId/slots-nuevo?fecha=YYYY-MM-DD&servicios=corte,barba
router.get('/:barberId/slots-nuevo', async (req, res) => {
  try {
    const { barberId } = req.params;
    const { fecha, servicios } = req.query;
    if (!fecha) return res.status(400).json({ error: 'Falta el parámetro fecha' });

    const disp = await BarberDisponibilidad.findOne({ barberId });
    if (!disp) return res.json({ slots: [] });

    const bloqueado = disp.diasBloqueados.some(d => d.fecha === fecha);
    if (bloqueado) return res.json({ slots: [] });

    const diaSemana = new Date(fecha + 'T12:00:00').getDay();
    const diaConfig = disp.diasDisponibles.find(d => d.dia === diaSemana);
    if (!diaConfig) return res.json({ slots: [] });

    // Calcular duración total según servicios seleccionados
    let duracionTotal = disp.duracionSlotMin ?? 30;
    if (servicios) {
      const serviciosArray = servicios.split(',').map(s => s.trim().toLowerCase());
      const duraciones = disp.duracionPorServicio ?? [];
      let suma = 0;
      for (const svc of serviciosArray) {
        const found = duraciones.find(d => d.nombre.toLowerCase() === svc);
        if (found) suma += found.duracionMin;
      }
      if (suma > 0) duracionTotal = suma;
    }

    // Generar slots según duración total del servicio
    const inicioMin = horaAMinutos(diaConfig.inicioHora);
    const finMin    = horaAMinutos(diaConfig.finHora);
    const slotBase  = disp.duracionSlotMin ?? 30; 
    const slotsBase = [];

   // DESPUÉS — genera cada slotBase (30 min siempre)
for (let min = inicioMin; min < finMin; min += slotBase) {
  slotsBase.push({ hora: minutosAHora(min), horaMinutos: min });
}

    // Filtrar slots pasados si es hoy
    const hoyLocal = new Date();
    const hoy = `${hoyLocal.getFullYear()}-${String(hoyLocal.getMonth()+1).padStart(2,'0')}-${String(hoyLocal.getDate()).padStart(2,'0')}`;

    console.log('Fecha solicitada:', fecha, '| Hoy:', hoy, '| Hora local:', hoyLocal.getHours() + ':' + hoyLocal.getMinutes());

    let slotsFiltrados = slotsBase;
    if (fecha === hoy) {
      const minutosActuales = hoyLocal.getHours() * 60 + hoyLocal.getMinutes() + 60;
      slotsFiltrados = slotsBase.filter(s => s.horaMinutos > minutosActuales);
    }

    // Filtrar slots ocupados
    const ocupados = await AgendaSlot.find({
      barberId: new mongoose.Types.ObjectId(barberId),
      fecha, status: 'ocupado'
    });
    const horasOcupadas = new Set(ocupados.map(s => s.hora));

    // Filtrar slots con espacio suficiente para la duración total
    const slotsDisponibles = slotsFiltrados.filter(slot => {
      if (horasOcupadas.has(slot.hora)) return false;
      const finSlot = slot.horaMinutos + duracionTotal;
      if (finSlot > finMin) return false;
      for (const s of slotsBase) {
        if (s.horaMinutos > slot.horaMinutos && s.horaMinutos < finSlot) {
          if (horasOcupadas.has(s.hora)) return false;
        }
      }
      return true;
    });

    res.json({ fecha, slots: slotsDisponibles, duracionTotal });
  } catch (error) {
    console.error('Error slots:', error.message);
    res.status(500).json({ error: 'Error del servidor' });
  }
});
// ── Helpers ───────────────────────────────────────────────────────
function horaAMinutos(hora) {
  const [h, m] = hora.split(':').map(Number);
  return h * 60 + m;
}

function minutosAHora(minutos) {
  const h = Math.floor(minutos / 60).toString().padStart(2, '0');
  const m = (minutos % 60).toString().padStart(2, '0');
  return `${h}:${m}`;
}

module.exports = router;