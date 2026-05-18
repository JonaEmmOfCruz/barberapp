import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

class UserReservationsScreen extends StatefulWidget {
  final String userId;
  const UserReservationsScreen({super.key, required this.userId});

  @override
  State<UserReservationsScreen> createState() => _UserReservationsScreenState();
}

class _UserReservationsScreenState extends State<UserReservationsScreen> {
  final String baseUrl = AppConfig.baseUrl;

  List<dynamic> _enCurso   = [];
  bool _isLoading          = true;
  Timer? _pollingTimer;
  final Map<String, String> _statusAnterior = {};

  final Set<String> _statusEnCurso = {
    'pendiente', 'aceptada', 'reagendada', 'en_proceso'
  };

  @override
  void initState() {
    super.initState();
    _fetchReservas();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchReservas(silencioso: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchReservas({bool silencioso = false}) async {
    if (!silencioso) setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/reservas/user/${widget.userId}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;

        // Detectar cambios de status y notificar
        for (final r in data) {
          final id     = r['_id']?.toString() ?? '';
          final status = r['status']?.toString() ?? '';
          final prev   = _statusAnterior[id];

          if (prev != null && prev != status) {
            if (status == 'en_camino') {
              _mostrarSnack('🚗 Tu barbero está en camino');
            } else if (status == 'en_proceso') {
              _mostrarSnack('✂️ ¡Tu barbero llegó! El servicio comenzó');
            }
          }
          _statusAnterior[id] = status;
        }

        if (mounted) {
          setState(() {
            _enCurso   = data.where((r) => _statusEnCurso.contains(r['status'])).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      extendBody: true,
      body: Column(
        children: [
          // ── HEADER ─────────────────────────────────────────────────
          Container(
            color: _kAzul,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    const Text('Mis Reservas',
                      style: TextStyle(color: _kBlanco, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Seguimiento de tus citas en curso',
                      style: TextStyle(color: _kBlanco.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          // ── CONTENIDO ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kAzulMedio))
                : RefreshIndicator(
                    color: _kAzulMedio,
                    onRefresh: _fetchReservas,
                    child: _enCurso.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _enCurso.length,
                            itemBuilder: (_, i) => _buildActiveCard(_enCurso[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(dynamic r) {
    final String nombre    = r['barberoNombre'] ?? 'Barbero';
    final String fecha     = r['fecha']?.toString() ?? '';
    final String hora      = r['hora'] ?? '';
    final String status    = r['status'] ?? 'pendiente';
    final List   servicios = r['servicios'] ?? [];
    final String domicilio = r['domicilio'] ?? '';

    Color badgeColor;
    String badgeLabel;
    Color badgeBg;
    switch (status) {
      case 'aceptada':
        badgeColor = const Color(0xFF7ECFFF);
        badgeBg    = const Color(0xFF1A5FD4).withOpacity(0.3);
        badgeLabel = 'Aceptada';
        break;
      case 'en_proceso':
        badgeColor = Colors.greenAccent;
        badgeBg    = Colors.green.withOpacity(0.2);
        badgeLabel = 'En proceso';
        break;
      case 'reagendada':
        badgeColor = const Color(0xFFFFB347);
        badgeBg    = Colors.orange.withOpacity(0.2);
        badgeLabel = 'Reagendada';
        break;
      default:
        badgeColor = const Color(0xFFFFB347);
        badgeBg    = Colors.orange.withOpacity(0.2);
        badgeLabel = 'Pendiente';
    }

    String horaFormateada = hora;
    try {
      final parts = hora.split(':');
      int h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      if (h == 0) {
        h = 12;
      } else if (h > 12) h -= 12;
      horaFormateada = '$h:$m $period';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(22),
        border: status == 'en_proceso'
            ? Border.all(color: Colors.green.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -20, right: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAzulMedio.withOpacity(0.2)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _kBlanco.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.person_rounded, color: _kBlanco, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                        style: const TextStyle(
                          color: _kBlanco, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (servicios.isNotEmpty)
                        Text(servicios.join(', '),
                          style: TextStyle(color: _kBlanco.withOpacity(0.55), fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(badgeLabel,
                    style: TextStyle(
                      color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 16),
              Container(height: 0.5, color: _kBlanco.withOpacity(0.1)),
              const SizedBox(height: 14),
              Row(children: [
                _buildDetail(Icons.calendar_today_rounded, fecha),
                const SizedBox(width: 16),
                _buildDetail(Icons.access_time_rounded, horaFormateada),
              ]),
              if (domicilio.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetail(Icons.location_on_rounded, domicilio),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(IconData icon, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF7ECFFF), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Icon(icon, color: _kBlanco.withOpacity(0.5), size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(texto,
            style: TextStyle(color: _kBlanco.withOpacity(0.7), fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _kNavy, borderRadius: BorderRadius.circular(24)),
              child: Icon(Icons.calendar_month_rounded,
                color: _kBlanco.withOpacity(0.5), size: 40)),
            const SizedBox(height: 16),
            const Text('Sin reservas en curso',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
            const SizedBox(height: 6),
            Text('Tus citas activas aparecerán aquí',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
        ),
      ],
    );
  }
}
