// Precios base por nivel de calificación
// Nivel: 'alto' = 4.5-5, 'medio' = 3-4.4, 'bajo' = 0-2.9 o nuevo

const PRECIOS_BASE = {
  alto: {
    'Corte':  250, 'Barba':  200, 'Ceja':  180,
    'Greka':  180, 'Tinte': 1100, 'Vapor':  150,
    'Mascarilla': 150,
  },
  medio: {
    'Corte':  180, 'Barba':  130, 'Ceja':  110,
    'Greka':  110, 'Tinte': 1030, 'Vapor':   80,
    'Mascarilla': 80,
  },
  bajo: {
    'Corte':  150, 'Barba':  100, 'Ceja':   80,
    'Greka':   80, 'Tinte': 1000, 'Vapor':   50,
    'Mascarilla': 50,
  },
};

const TARIFA_KM = { alto: 11, medio: 8, bajo: 7 };
const COMISION_APP  = 0.15;
const IVA           = 0.16;
const MINIMO_RESENAS = 10; // reseñas mínimas para subir de nivel

function getNivel(promedio, totalResenias) {
  if (totalResenias < MINIMO_RESENAS) return 'bajo'; // barbero nuevo
  if (promedio >= 4.5) return 'alto';
  if (promedio >= 3.0) return 'medio';
  return 'bajo';
}

function getPrecioBase(servicios, nivel) {
  const tabla = PRECIOS_BASE[nivel];
  return servicios.reduce((total, servicio) => {
    return total + (tabla[servicio] ?? 0);
  }, 0);
}

function calcularPrecio(servicios, distanciaKm, promedio, totalResenias) {
  const nivel        = getNivel(promedio, totalResenias);
  const tarifaKm     = TARIFA_KM[nivel];
  const precioBase   = getPrecioBase(servicios, nivel);
  const traslado     = distanciaKm * tarifaKm;
  const ingBarbero   = precioBase + traslado;
  const comision     = ingBarbero * COMISION_APP;
  const subtotal     = ingBarbero + comision;
  const total        = Math.round(subtotal * (1 + IVA));

  return {
    nivel,
    precioBase,
    traslado:    Math.round(traslado),
    ingBarbero:  Math.round(ingBarbero),
    comision:    Math.round(comision),
    subtotal:    Math.round(subtotal),
    total,
  };
}

module.exports = { calcularPrecio, getNivel, PRECIOS_BASE, TARIFA_KM };