import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/screens/User_Screens/booking_screen.dart';

const _kAzul = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy = Color(0xFF1A1A2E);
const _kBlanco = Colors.white;
const _kFondo = Color(0xFFF0F4FF);

class UserAgendaScreen extends StatefulWidget {
  final String userId;
  const UserAgendaScreen({super.key, required this.userId});

  @override
  State<UserAgendaScreen> createState() => _UserAgendaScreenState();
}

class _UserAgendaScreenState extends State<UserAgendaScreen> {
  final String baseUrl = AppConfig.baseUrl;
  List<dynamic> _barberos = [];
  bool _isLoading = true;
  final Set<String> _favoritos = {};
  String _currentAddress = "Obteniendo ubicación...";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _determinePosition();
    await _fetchFavorites();
    await _fetchBarbers();
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentAddress = "Permiso denegado");
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(
          () => _currentAddress =
              "${placemarks[0].street}, ${placemarks[0].locality}",
        );
      }
    } catch (_) {
      setState(() => _currentAddress = "Ubicación no disponible");
    }
  }

  Future<void> _fetchFavorites() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/barbers/favorites/${widget.userId}'),
      );
      if (res.statusCode == 200) {
        final List<dynamic> favs = jsonDecode(res.body);
        setState(() {
          for (var f in favs) {
            _favoritos.add(f['_id']?.toString() ?? '');
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBarbers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/barbers/disponibles'));
      if (res.statusCode == 200) {
        setState(() {
          _barberos = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(dynamic barbero) async {
    final String barberId = barbero['barberId']?.toString() ?? '';
    setState(() {
      if (_favoritos.contains(barberId)) {
        _favoritos.remove(barberId);
      } else {
        _favoritos.add(barberId);
      }
    });
    try {
      await http.post(
        Uri.parse('$baseUrl/api/barbers/favorite'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': widget.userId, 'barberId': barberId}),
      );
    } catch (_) {
      _fetchFavorites();
    }
  }

  String _horarioResumen(dynamic barbero) {
    final diasConfig = barbero['diasDisponibles'] as List? ?? [];
    if (diasConfig.isEmpty) return '';

    const diasSem = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final diasOrdenados = List<Map<String, dynamic>>.from(diasConfig)
      ..sort((a, b) => (a['dia'] as int).compareTo(b['dia'] as int));

    // Días
    final nombresDias = diasOrdenados
        .map((d) => diasSem[d['dia'] as int])
        .toList();

    // Agrupar días consecutivos: Lun-Vie en lugar de Lun·Mar·Mié·Jue·Vie
    String diasStr;
    if (nombresDias.length >= 3) {
      diasStr = '${nombresDias.first} - ${nombresDias.last}';
    } else {
      diasStr = nombresDias.join(' · ');
    }

    // Horario del primer día como referencia
    final primerDia = diasOrdenados.first;
    final inicioHora = primerDia['inicioHora'] ?? '';
    final finHora = primerDia['finHora'] ?? '';

    return '$diasStr  ·  ${_formatHora(inicioHora)} - ${_formatHora(finHora)}';
  }

  String _formatHora(String hora24) {
    if (hora24.isEmpty) return '';
    final parts = hora24.split(':');
    int h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) {
      h = 12;
    } else if (h > 12)
      h -= 12;
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kAzulMedio),
                  )
                : RefreshIndicator(
                    color: _kAzulMedio,
                    onRefresh: _fetchBarbers,
                    child: _barberos.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _barberos.length,
                            itemBuilder: (_, i) =>
                                _buildBarberCard(_barberos[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kAzul,
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kBlanco.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: _kBlanco,
                    size: 16,
                  ),
                ),
              ),
              const Text(
                'Reservar cita',
                style: TextStyle(
                  color: _kBlanco,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige tu barbero y agenda',
                style: TextStyle(
                  color: _kBlanco.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7ECFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _currentAddress,
                      style: TextStyle(
                        color: _kBlanco.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarberCard(dynamic b) {
    final String nombre = b['nombre'] ?? 'Barbero';
    final String barberId = b['barberId']?.toString() ?? '';
    final String ciudad = b['ciudad'] ?? '';
    final String? profileImage = b['profileImage'];
    final bool esFav = _favoritos.contains(barberId);
    final String horario = _horarioResumen(b);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBlanco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8FF), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFEEF4FF),
              image: profileImage != null
                  ? DecorationImage(
                      image: NetworkImage('$baseUrl$profileImage'),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: profileImage == null
                ? const Icon(Icons.person_rounded, color: _kAzulMedio, size: 34)
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
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kNavy,
                      ),
                    ),
                    // Después de Text(nombre, ...)
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final promedio = (b['calificacion']?['promedio'] ?? 0)
                              .toDouble();
                          return Icon(
                            i < promedio.floor()
                                ? Icons.star_rounded
                                : i < promedio
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFFFC107),
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          '${(b['calificacion']?['promedio'] ?? 0).toStringAsFixed(1)} (${b['calificacion']?['totalReseñas'] ?? 0})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8892B0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _toggleFavorite(b),
                      child: Icon(
                        esFav
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        color: _kAzulMedio,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                if (ciudad.isNotEmpty)
                  Text(
                    ciudad,
                    style: const TextStyle(
                      color: Color(0xFF8892B0),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 8),
                if (horario.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: _kAzulMedio,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          horario,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kNavy,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BookingScreen(barber: b, userId: widget.userId),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Agendar',
                      style: TextStyle(
                        color: _kBlanco,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.content_cut_rounded,
                  color: _kBlanco.withOpacity(0.5),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin barberos disponibles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Intenta más tarde',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
