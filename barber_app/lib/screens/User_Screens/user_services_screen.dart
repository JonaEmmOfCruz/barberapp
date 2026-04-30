import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      if (_userId == null) { setState(() => _isLoading = false); return; }
      final res = await http.get(
        Uri.parse('$baseUrl/api/service-requests/user/$_userId/historial'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() { _historial = jsonDecode(res.body); _isLoading = false; });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error historial: $e');
      setState(() => _isLoading = false);
    }
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
                    child: _filtrado.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filtrado.length,
                            itemBuilder: (_, i) => _buildCard(_filtrado[i]),
                          ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildLiquidBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kAzul,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24, right: 24, bottom: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kBlanco.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: _kBlanco, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Text('Mis servicios',
            style: TextStyle(color: _kBlanco, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
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
            '${_historial.where((h) => h['tipo'] == 'agendada').length}', 'Agendadas')),
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

  Widget _buildCard(dynamic item) {
    final bool   esRunner      = item['tipo'] == 'runner';
    final String nombre        = item['barberoNombre'] ?? (esRunner ? 'No asignado' : 'Barbero');
    final dynamic rawServicios = item['servicios'];
    final String servicios     = rawServicios is List
        ? rawServicios.join(', ')
        : rawServicios?.toString() ?? 'Sin servicios';
    final String status        = item['status'] ?? (esRunner ? 'buscando' : 'pendiente');
    final String fecha         = item['fecha']?.toString() ?? '';
    final String hora          = item['hora']?.toString() ?? '';

    Color statusColor;
    String statusLabel;
    if (esRunner) {
      switch (status) {
        case 'finalizado':       statusColor = const Color(0xFF2E7D32); statusLabel = 'Completado';  break;
        case 'en_servicio':      statusColor = Colors.orange;           statusLabel = 'En servicio'; break;
        case 'en_camino':        statusColor = Colors.blue;             statusLabel = 'En camino';   break;
        case 'barbero_asignado': statusColor = Colors.blue;             statusLabel = 'Asignado';    break;
        case 'cancelado':        statusColor = Colors.red;              statusLabel = 'Cancelado';   break;
        default:                 statusColor = Colors.grey;             statusLabel = 'Buscando';
      }
    } else {
      switch (status) {
        case 'completada': statusColor = const Color(0xFF2E7D32); statusLabel = 'Completada'; break;
        case 'aceptada':   statusColor = _kAzulMedio;             statusLabel = 'Aceptada';   break;
        case 'rechazada':  statusColor = Colors.red;              statusLabel = 'Rechazada';  break;
        case 'reagendada': statusColor = Colors.orange;           statusLabel = 'Reagendada'; break;
        case 'cancelada':  statusColor = Colors.red;              statusLabel = 'Cancelada';  break;
        default:           statusColor = Colors.grey;             statusLabel = 'Pendiente';
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
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              esRunner ? Icons.location_on_rounded : Icons.calendar_month_rounded,
              color: _kAzulMedio, size: 26),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: esRunner ? _kAzul.withOpacity(0.08) : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(children: [
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

  Widget _buildLiquidBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: _kBlanco.withOpacity(0.25),
              border: Border.all(color: _kBlanco.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(Icons.home_filled,    'Inicio',    false, () => Navigator.pop(context)),
                _buildTabItem(Icons.description,    'Servicios', true,  () {}),
                _buildTabItem(Icons.calendar_month, 'Reservas',  false, () =>
                  Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => UserReservationsScreen(userId: _userId ?? '')))),
                _buildTabItem(Icons.person,         'Perfil',    false, () =>
                  Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => const UserPerfilScreen()))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22,
            color: selected ? Colors.grey.shade500 : _kAzulMedio),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.grey.shade500 : _kAzulMedio)),
        ],
      ),
    );
  }
}
