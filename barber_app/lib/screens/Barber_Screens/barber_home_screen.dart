import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/config/app_config.dart';
import 'barber_servicios_screen.dart';
import 'barber_citas_screen.dart';
import 'barber_store_screen.dart';
import 'Barber_Profile_screen.dart';
import 'liquid_glass_bar.dart';

class BarberHomeScreen extends StatefulWidget {
  final String barberId;
  final String barberName;

  const BarberHomeScreen({
    super.key,
    required this.barberId,
    required this.barberName,
  });

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  int _selectedIndex = 0;

  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  final String baseUrl = AppConfig.baseUrl;
  String _realAddress = "Obteniendo ubicación...";
  bool _isAvailable = false;
  String _workMode  = 'offline';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchProfileImage();
    _cargarEstado();
  }

  // ── CARGAR ESTADO INICIAL DEL BACKEND ───────────────────────────
  Future<void> _cargarEstado() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/estado'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _isAvailable = data['isAvailable'] ?? false;
          _workMode    = data['workMode'] ?? 'offline';
        });
      }
    } catch (e) {
      debugPrint('Error cargando estado: $e');
    }
  }

  // ── TOGGLE DISPONIBILIDAD ────────────────────────────────────────
  Future<void> _toggleDisponibilidad(bool v) async {
    // Cambio optimista — actualiza la UI de inmediato
    setState(() => _isAvailable = v);

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'isAvailable': v,
          'lat': _currentLatLng?.latitude,
          'lng': _currentLatLng?.longitude,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _workMode = data['workMode'] ?? _workMode);
        debugPrint('WorkMode: ${data['workMode']} — ${data['msg']}');
      } else {
        // Revertimos si el backend falló
        setState(() => _isAvailable = !v);
      }
    } catch (e) {
      // Revertimos si hay error de red
      setState(() => _isAvailable = !v);
      debugPrint('Error toggle: $e');
    }
  }

  // ── UBICACIÓN ────────────────────────────────────────────────────
  Future<void> _fetchProfileImage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/upload/barber-documents/${widget.barberId}'),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final data = res['data'];
        if (data != null && data['profileImage'] != null) {
          setState(() {
            _profileImageUrl = data['profileImage'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error al cargar foto en Home: $e");
    }
  }

  Future<void> _determinePosition() async {
    try {
      // 1. Muestra la última ubicación conocida de inmediato
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        setState(() {
          _currentLatLng = LatLng(lastPosition.latitude, lastPosition.longitude);
        });
        _centerMapWithZoom();
      }

      // 2. Obtiene la ubicación precisa en segundo plano
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _realAddress   = "${placemarks[0].street}, ${placemarks[0].locality}";
      });
      _centerMapWithZoom();

    } catch (e) {
      _currentLatLng = const LatLng(20.7219, -103.3911);
      _centerMapWithZoom();
    }
  }

  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLatLng!, zoom: 17.5),
      ));
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMapSection(),
          BarberServicesScreen(barberId: widget.barberId),
          BarberAppointmentsScreen(barberId: widget.barberId),
          BarberStoreScreen(barberId: widget.barberId),
          BarberProfileScreen(
            barberId: widget.barberId,
            barberName: widget.barberName,
            onBack: () { setState(() { _selectedIndex = 0; }); },
          ),
        ],
      ),
      bottomNavigationBar: LiquidGlassBar(
        currentIndex: _selectedIndex,
        barberId: widget.barberId,
        barberName: widget.barberName,
        onTap: (index) { setState(() { _selectedIndex = index; }); },
      ),
    );
  }

  // ── MAPA ──────────────────────────────────────────────────────────
  Widget _buildMapSection() {
    return Stack(
      children: [
        _currentLatLng == null
            ? const Center(child: CircularProgressIndicator())
            : AppleMap(
                initialCameraPosition: CameraPosition(target: _currentLatLng!, zoom: 16),
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),

        Positioned(
          right: 20,
          bottom: 225,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: () => _centerMapWithZoom(),
            child: const Icon(Icons.my_location, color: Color(0xFFFD2424)),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(),
              _buildLocationCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBarberAvatar(),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bienvenido ${widget.barberName}",
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF242424)),
                  ),
                  const Text(
                    "Selecciona tu disponibilidad",
                    style: TextStyle(color: Color(0xFF242424), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Switch(
                value: _isAvailable,
                onChanged: _toggleDisponibilidad,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
              ),
              const SizedBox(width: 8),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAvailable ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _modoTexto(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF242424)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Texto del modo actual
  String _modoTexto() {
    switch (_workMode) {
      case 'runner':  return 'Disponible';
      case 'agenda':  return 'Modo Agenda';
      case 'hibrido': return 'Modo Híbrido';
      default:        return 'No disponible';
    }
  }

  // ── LOCATION CARD ─────────────────────────────────────────────────
  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.redAccent, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tu Ubicación actual",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(_realAddress,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AVATAR ────────────────────────────────────────────────────────
  Widget _buildBarberAvatar() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
        image: _profileImageUrl != null
            ? DecorationImage(
                image: NetworkImage('$baseUrl$_profileImageUrl'),
                fit: BoxFit.cover)
            : null,
      ),
      child: _profileImageUrl == null
          ? const Icon(Icons.person, color: Colors.grey)
          : null,
    );
  }
}