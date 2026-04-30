import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/screens/User_Screens/booking_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

class UserAgendaScreen extends StatefulWidget {
  final String userId;
  const UserAgendaScreen({super.key, required this.userId});

  @override
  State<UserAgendaScreen> createState() => _UserAgendaScreenState();
}

class _UserAgendaScreenState extends State<UserAgendaScreen> {
  final String baseUrl = AppConfig.baseUrl;
  List<dynamic>     _barberos  = [];
  bool              _isLoading = true;
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
        position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() => _currentAddress =
            "${placemarks[0].street}, ${placemarks[0].locality}");
      }
    } catch (_) {
      setState(() => _currentAddress = "Ubicación no disponible");
    }
  }

  Future<void> _fetchFavorites() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/barbers/favorites/${widget.userId}'));
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
          _barberos  = jsonDecode(res.body);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      extendBody: true,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kAzulMedio))
                : RefreshIndicator(
                    color: _kAzulMedio,
                    onRefresh: _fetchBarbers,
                    child: _barberos.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _barberos.length,
                            itemBuilder: (_, i) => _buildBarberCard(_barberos[i]),
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
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 14),
              const Text('Reservar cita',
                style: TextStyle(color: _kBlanco, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Barberos disponibles hoy',
                style: TextStyle(color: _kBlanco.withOpacity(0.6), fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF7ECFFF), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_currentAddress,
                      style: TextStyle(color: _kBlanco.withOpacity(0.7), fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final String  nombre       = b['nombre']             ?? 'Barbero';
    final String  barberId     = b['barberId']?.toString() ?? '';
    final String  ciudad       = b['ciudad']             ?? '';
    final String  fecha        = b['fecha']              ?? '';
    final List    slots        = b['slots']              ?? [];
    final String? profileImage = b['profileImage'];
    final bool    esFav        = _favoritos.contains(barberId);

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
            width: 64, height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFFEEF4FF),
              image: profileImage != null
                  ? DecorationImage(
                      image: NetworkImage('$baseUrl$profileImage'),
                      fit: BoxFit.cover)
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
                    Text(nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
                    GestureDetector(
                      onTap: () => _toggleFavorite(b),
                      child: Icon(
                        esFav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                        color: _kAzulMedio, size: 22),
                    ),
                  ],
                ),
                if (ciudad.isNotEmpty)
                  Text(ciudad, style: const TextStyle(color: Color(0xFF8892B0), fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip(Icons.calendar_today_rounded, fecha),
                    const SizedBox(width: 8),
                    _buildChip(Icons.access_time_rounded, '${slots.length} slots'),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BookingScreen(barber: b, userId: widget.userId))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Agendar',
                      style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _kFondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _kAzulMedio),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 11, color: _kNavy, fontWeight: FontWeight.w600)),
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
                width: 80, height: 80,
                decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(24)),
                child: Icon(Icons.content_cut_rounded, color: _kBlanco.withOpacity(0.5), size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Sin barberos disponibles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
              const SizedBox(height: 6),
              Text('Intenta más tarde',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ],
    );
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
                _buildTabItem(Icons.description,    'Servicios', false, () =>
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserServicesScreen()))),
                _buildTabItem(Icons.calendar_month, 'Reservas',  false, () =>
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserReservationsScreen(userId: widget.userId)))),
                _buildTabItem(Icons.person,         'Perfil',    false, () =>
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserPerfilScreen()))),
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
          Icon(icon, size: 22, color: selected ? Colors.grey.shade500 : _kAzulMedio),
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
