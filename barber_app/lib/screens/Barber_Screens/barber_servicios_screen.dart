import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:barber_app/config/app_config.dart';

// ─────────────────────────────────────────────
//  MODELO
// ─────────────────────────────────────────────

class ServicioHistorial {
  final String id;
  final String tipo; // 'Runner' | 'Cita'
  final String servicios;
  final double ganancia;
  final int duracionMin;
  final DateTime fecha;
  final String? clienteNombre;
  final String? clienteFoto;

  ServicioHistorial({
    required this.id,
    required this.tipo,
    required this.servicios,
    required this.ganancia,
    required this.duracionMin,
    required this.fecha,
    this.clienteNombre,
    this.clienteFoto,
  });

  factory ServicioHistorial.fromJson(Map<String, dynamic> json) {
    return ServicioHistorial(
      id:             json['_id'] ?? '',
      tipo:           json['tipo'] ?? 'Runner',
      servicios:      json['servicios'] ?? 'Servicio general',
      ganancia:       (json['ganancia'] ?? 0).toDouble(),
      duracionMin:    json['duracionMin'] ?? 0,
      fecha:          DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
      clienteNombre:  json['clienteNombre'],
      clienteFoto:    json['clienteFoto'],
    );
  }

  String get horaFormateada {
    final h = fecha.hour.toString().padLeft(2, '0');
    final m = fecha.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
//  COLORES
// ─────────────────────────────────────────────

const _kRojo      = Color(0xFFE8202A);
const _kNegro     = Color(0xFF1A1A1A);
const _kGrisFondo = Color(0xFFF5F5F5);
const _kBlanco    = Colors.white;

// ─────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────

class BarberServicesScreen extends StatefulWidget {
  final String? barberId;
  final String? barberName;

  const BarberServicesScreen({super.key, this.barberId, this.barberName});

  @override
  State<BarberServicesScreen> createState() => _BarberServicesScreenState();
}

class _BarberServicesScreenState extends State<BarberServicesScreen> {
  final String baseUrl = AppConfig.baseUrl;

  String _filtro         = 'Hoy';
  bool   _isLoading      = true;
  double _totalGanancia  = 0;
  int    _totalServicios = 0;
  List<ServicioHistorial> _servicios = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        '$baseUrl/api/servicios/stats/${widget.barberId}?filtro=$_filtro',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final lista = (data['servicios'] as List? ?? [])
            .map((s) => ServicioHistorial.fromJson(s))
            .toList();
        setState(() {
          _totalGanancia  = (data['gananciaTotal'] ?? 0).toDouble();
          _totalServicios = lista.length;
          _servicios      = lista;
          _isLoading      = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetchData servicios: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kGrisFondo,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kRojo))
                : RefreshIndicator(
                    color: _kRojo,
                    onRefresh: _fetchData,
                    child: _buildContenido(),
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
 Widget _buildHeader() {
  return Container(
    color: _kRojo,
    child: SafeArea(
      bottom: false,
      child: Container(
        color: _kRojo,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis servicios',
              style: TextStyle(color: _kBlanco, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_fechaFormateado(),
              style: TextStyle(color: _kBlanco.withOpacity(0.75), fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

  // ── CONTENIDO ─────────────────────────────────────────────────────
  Widget _buildContenido() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        _buildStatsRow(),
        const SizedBox(height: 14),
        _buildFiltros(),
        const SizedBox(height: 16),
        _buildSeccionLabel('Historial'),
        const SizedBox(height: 12),
        _buildListaServicios(),
        const SizedBox(height: 110),
      ],
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Ganancias',
            valor: '\$${_totalGanancia.toStringAsFixed(0)}',
            valorColor: const Color(0xFF16A34A),
            sub: _filtro.toLowerCase(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: 'Servicios',
            valor: '$_totalServicios',
            valorColor: _kNegro,
            sub: 'completados',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String valor,
    required Color valorColor,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(valor,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: valorColor)),
          const SizedBox(height: 2),
          Text(sub,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ── FILTROS ───────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Row(
      children: ['Hoy', 'Semana', 'Mes'].map((f) {
        final activo = f == _filtro;
        return GestureDetector(
          onTap: () {
            if (_filtro != f) {
              setState(() => _filtro = f);
              _fetchData();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: activo ? _kRojo : _kBlanco,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activo ? _kRojo : Colors.grey.shade200,
                width: 0.5,
              ),
            ),
            child: Text(f,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: activo ? _kBlanco : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── LISTA ─────────────────────────────────────────────────────────
  // Agrupa los servicios por fecha
Map<String, List<ServicioHistorial>> _agruparPorFecha() {
  final Map<String, List<ServicioHistorial>> grupos = {};
  for (final s in _servicios) {
    final key = _labelFecha(s.fecha);
    grupos.putIfAbsent(key, () => []).add(s);
  }
  return grupos;
}

// Convierte la fecha a label legible
String _labelFecha(DateTime fecha) {
  final hoy   = DateTime.now();
  final ayer  = hoy.subtract(const Duration(days: 1));
  const dias  = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
  const meses = ['enero','febrero','marzo','abril','mayo','junio',
                 'julio','agosto','septiembre','octubre','noviembre','diciembre'];

  if (fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day) {
    return 'Hoy';
  } else if (fecha.year == ayer.year && fecha.month == ayer.month && fecha.day == ayer.day) {
    return 'Ayer';
  } else {
    return '${dias[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1]}';
  }
}

Widget _buildListaServicios() {
  if (_servicios.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kBlanco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Sin servicios en este período',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // Solo agrupa si el filtro es Semana o Mes
  if (_filtro == 'Hoy') {
    return Column(children: _servicios.map((s) => _buildServiceCard(s)).toList());
  }

  final grupos = _agruparPorFecha();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: grupos.entries.map((entry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Separador de fecha
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              children: [
                Container(width: 4, height: 14,
                  decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(entry.key,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 0.5, color: Colors.grey.shade300)),
              ],
            ),
          ),
          ...entry.value.map((s) => _buildServiceCard(s)),
          const SizedBox(height: 8),
        ],
      );
    }).toList(),
  );
}
  Widget _buildServiceCard(ServicioHistorial servicio) {
    final esRunner = servicio.tipo == 'Runner';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlanco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Row(
        children: [
          // Avatar del cliente
          _buildAvatar(servicio),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio.clienteNombre ?? 'Cliente atendido',
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _kNegro),
                ),
                const SizedBox(height: 2),
                Text(servicio.servicios,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetaItem(Icons.payments_outlined,
                      '\$${servicio.ganancia.toStringAsFixed(0)}'),
                    const SizedBox(width: 10),
                    _buildMetaItem(Icons.timer_outlined,
                      '${servicio.duracionMin} min'),
                    const SizedBox(width: 10),
                    _buildMetaItem(Icons.access_time_outlined,
                      servicio.horaFormateada),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Badge tipo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: esRunner
                  ? _kRojo.withOpacity(0.08)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              servicio.tipo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: esRunner ? _kRojo : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Avatar con foto real o ícono por defecto
  Widget _buildAvatar(ServicioHistorial servicio) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        shape: BoxShape.circle,
        image: servicio.clienteFoto != null
            ? DecorationImage(
                image: NetworkImage('$baseUrl${servicio.clienteFoto}'),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: servicio.clienteFoto == null
          ? const Icon(Icons.person, color: _kRojo, size: 26)
          : null,
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _kRojo),
        const SizedBox(width: 3),
        Text(text,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSeccionLabel(String titulo) {
    return Row(
      children: [
        Container(
          width: 4, height: 16,
          decoration: BoxDecoration(color: _kRojo, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(titulo,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNegro)),
      ],
    );
  }

  String _fechaFormateado() {
    const dias  = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    const meses = ['enero','febrero','marzo','abril','mayo','junio',
                   'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final now = DateTime.now();
    return '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]}';
  }
}