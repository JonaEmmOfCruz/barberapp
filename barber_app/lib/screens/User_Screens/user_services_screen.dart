import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/config/app_config.dart';

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

class UserServicesScreen extends StatefulWidget {
  const UserServicesScreen({super.key});
  @override
  State<UserServicesScreen> createState() => _UserServicesScreenState();
}

class _UserServicesScreenState extends State<UserServicesScreen> {
  final String baseUrl = AppConfig.baseUrl;
  List<dynamic> _historial = [];
  bool   _isLoading = true;
  String _filtro    = 'Todos';
  String? _userId;

  List<dynamic> get _filtrado {
    if (_filtro == 'Todos') return _historial;
    final key = _filtro == 'Runner' ? 'runner' : 'agendada';
    return _historial.where((h) => h['tipo'] == key).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchHistorial();
  }

  Future<void> _fetchHistorial() async {
    setState(() => _isLoading = true);
    _historial = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      if (_userId == null) { setState(() => _isLoading = false); return; }

      final res = await http.get(
        Uri.parse('$baseUrl/api/service-requests/user/$_userId/historial'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() => _historial = jsonDecode(res.body));
      }
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error historial: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── DIALOG CALIFICAR ──────────────────────────────────────────────
  void _mostrarDialogCalificar(dynamic item) {
    int estrellas = 0;
    showDialog(
      context: context,
      barrierColor: const Color(0xFF0F1428).withOpacity(0.75),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: const BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A4E),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                      image: item['barberoFoto'] != null
                          ? DecorationImage(
                              image: NetworkImage('$baseUrl${item['barberoFoto']}'),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: item['barberoFoto'] == null
                        ? Center(
                            child: Text(
                              (item['barberoNombre'] ?? 'B')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _kBlanco)))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(item['barberoNombre'] ?? 'Barbero',
                    style: const TextStyle(color: _kBlanco, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${(item['servicios'] as List? ?? []).join(', ')} · ${item['fecha'] ?? ''}',
                    style: TextStyle(color: _kBlanco.withOpacity(0.45), fontSize: 12)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Text('¿Cómo fue tu experiencia?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () => setDialog(() => estrellas = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          i < estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFF59E0B), size: 42)),
                    )),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    estrellas == 0 ? 'Toca para calificar'
                    : estrellas == 1 ? 'Muy malo'
                    : estrellas == 2 ? 'Malo'
                    : estrellas == 3 ? 'Regular'
                    : estrellas == 4 ? 'Bueno'
                    : 'Excelente',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: estrellas == 0 ? Colors.grey.shade400 : const Color(0xFFF59E0B))),
                  const SizedBox(height: 20),
                  Container(height: 0.5, color: const Color(0xFFF0F4FF)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E8FF), width: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: Text('Ahora no',
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: estrellas == 0 ? null : () async {
                          Navigator.pop(context);
                          await _enviarCalificacion(item, estrellas);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kNavy,
                          disabledBackgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0),
                        child: const Text('Enviar',
                          style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviarCalificacion(dynamic item, int estrellas) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/barbers/${item['barberoId']}/calificar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId':    _userId,
          'reservaId': item['_id'],
          'estrellas': estrellas,
        }),
      );
      if (res.statusCode == 200) {
        _mostrarSnack('¡Gracias por tu calificación!');
        _fetchHistorial();
      } else {
        _mostrarSnack('Error al enviar calificación');
      }
    } catch (_) {
      _mostrarSnack('Error de conexión');
    }
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      extendBody: true,
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltros(),
          _buildStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kAzulMedio))
                : RefreshIndicator(
                    color: _kAzulMedio,
                    onRefresh: _fetchHistorial,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (_filtrado.isNotEmpty) ...[
                          _buildSeccionLabel('Historial'),
                          ..._filtrado.map((h) => _buildCard(h)),
                        ],
                        if (_filtrado.isEmpty)
                          _buildEmpty(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _kAzul,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24, right: 24, bottom: 24,
      ),
      child: const Text('Mis servicios',
        style: TextStyle(color: _kBlanco, fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: _kAzul,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: ['Todos', 'Runner', 'Agendada'].map((f) {
          final activo = f == _filtro;
          return GestureDetector(
            onTap: () => setState(() => _filtro = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: activo ? _kBlanco : _kBlanco.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(f, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: activo ? _kAzul : _kBlanco)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(child: _buildStatPill('${_historial.length}', 'Total')),
          const SizedBox(width: 8),
          Expanded(child: _buildStatPill(
            '${_historial.where((h) => h['tipo'] == 'runner').length}', 'Runner')),
          const SizedBox(width: 8),
          Expanded(child: _buildStatPill(
            '${_historial.where((h) => h['tipo'] == 'agendada').length}', 'Agendada')),
        ],
      ),
    );
  }

  Widget _buildStatPill(String valor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBlanco.withOpacity(0.08), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(valor,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kBlanco)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: _kBlanco.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildSeccionLabel(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Container(width: 4, height: 14,
          decoration: BoxDecoration(color: _kAzulMedio, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(titulo,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kNavy)),
      ]),
    );
  }

  // ── CARD HISTORIAL ────────────────────────────────────────────────
  Widget _buildCard(dynamic item) {
    final bool   esRunner      = item['tipo'] == 'runner';
    final String nombre        = item['barberoNombre'] ?? (esRunner ? 'No asignado' : 'Barbero');
    final dynamic rawServicios = item['servicios'];
    final String servicios     = rawServicios is List
        ? rawServicios.join(', ')
        : rawServicios?.toString() ?? 'Sin servicios';
    final String status        = item['status'] ?? (esRunner ? 'finalizado' : 'completada');
    final String fecha         = item['fecha']?.toString() ?? '';
    final String hora          = item['hora']?.toString() ?? '';
    final String? barberoFoto  = item['barberoFoto']?.toString();
    final bool   calificado    = item['calificado'] ?? false;

    // Status que permiten calificar
    final bool puedeCalificar  = (status == 'finalizado' || status == 'completada') && !calificado;

    Color statusColor;
    String statusLabel;
    if (esRunner) {
      switch (status) {
        case 'finalizado': statusColor = const Color(0xFF2E7D32); statusLabel = 'Completado'; break;
        case 'cancelado':  statusColor = Colors.red;              statusLabel = 'Cancelado';  break;
        default:           statusColor = Colors.grey;             statusLabel = status;
      }
    } else {
      switch (status) {
        case 'completada': statusColor = const Color(0xFF2E7D32); statusLabel = 'Completada'; break;
        case 'rechazada':  statusColor = Colors.red;              statusLabel = 'Rechazada';  break;
        case 'cancelada':  statusColor = Colors.red;              statusLabel = 'Cancelada';  break;
        default:           statusColor = Colors.grey;             statusLabel = status;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBlanco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila principal ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(16),
                  image: barberoFoto != null
                      ? DecorationImage(
                          image: NetworkImage('$baseUrl$barberoFoto'),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: barberoFoto == null
                    ? Icon(
                        esRunner ? Icons.location_on_rounded : Icons.calendar_month_rounded,
                        color: _kAzulMedio, size: 26)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(nombre,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(servicios,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8892B0)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: esRunner ? _kAzul.withOpacity(0.08) : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(esRunner ? 'Runner' : 'Agendada',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: esRunner ? _kAzul : _kAzulMedio)),
                      ),
                      if (fecha.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(fecha, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                      if (hora.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(hora, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),

          // ── Botón calificar ─────────────────────────────────────
          if (puedeCalificar) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFEEF4FF), height: 1),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mostrarDialogCalificar(item),
                icon: const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                label: const Text('Calificar servicio',
                  style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0),
              ),
            ),
          ] else if (calificado) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFEEF4FF), height: 1),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              Text('Ya calificaste este servicio',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(children: [
      const SizedBox(height: 80),
      Center(child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.receipt_long_rounded, color: _kAzulMedio, size: 40)),
        const SizedBox(height: 16),
        const Text('Sin servicios aún',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
        const SizedBox(height: 6),
        Text('Tus servicios aparecerán aquí',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ])),
    ]);
  }
}