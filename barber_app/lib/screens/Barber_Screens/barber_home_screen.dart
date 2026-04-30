import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
import 'barber_state.dart';
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

  late BarberState _barberState;

  AppleMapController? _mapController;
  LatLng?  _currentLatLng;
  String   _realAddress   = "Obteniendo ubicación...";
  String?  _profileImageUrl;
  final String baseUrl    = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _barberState = BarberState(barberId: widget.barberId);
    _barberState.cargarEstado();
    _determinePosition();
    _fetchProfileImage();
  }

  @override
  void dispose() {
    _barberState.dispose();
    super.dispose();
  }

  Future<void> _actualizarUbicacionBackend(double lat, double lng) async {
  try {
    await http.put(
      Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/ubicacion'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'lat': lat, 'lng': lng}),
    );
    debugPrint('Ubicación actualizada en backend: $lat, $lng');
  } catch (e) {
    debugPrint('Error actualizando ubicación: $e');
  }
}

  Future<void> _determinePosition() async {
    try {
      // 1. Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _realAddress   = "Permiso denegado";
            _currentLatLng = const LatLng(20.7219, -103.3911);
          });
          _centerMapWithZoom();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _realAddress   = "Activa la ubicación en Ajustes";
          _currentLatLng = const LatLng(20.7219, -103.3911);
        });
        _centerMapWithZoom();
        
        return;
      }

      // 2. Última ubicación conocida (instantáneo)
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        setState(() {
          _currentLatLng = LatLng(lastPosition.latitude, lastPosition.longitude);
          _realAddress   = "Cargando dirección...";
        });
        _centerMapWithZoom();
      }

      // 3. Ubicación precisa con timeout de 10 segundos
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('timeout'),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _realAddress   = "${placemarks[0].street}, ${placemarks[0].locality}";
      });
      _centerMapWithZoom();
      _actualizarUbicacionBackend(position.latitude, position.longitude);

    } catch (e) {
      if (_currentLatLng == null) {
        _currentLatLng = const LatLng(20.7219, -103.3911);
        _centerMapWithZoom();
      }
      setState(() {
        if (_realAddress == "Obteniendo ubicación..." ||
            _realAddress == "Cargando dirección...") {
          _realAddress = "Ubicación aproximada";
        }
      });
    }
  }

  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLatLng!, zoom: 17.5),
      ));
    }
  }

  Future<void> _fetchProfileImage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/upload/barber-documents/${widget.barberId}'),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final data = res['data'];
        if (data != null && data['profileImage'] != null) {
          setState(() => _profileImageUrl = data['profileImage']);
        }
      }
    } catch (e) {
      debugPrint("Error al cargar foto: $e");
    }
  }

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
    BarberAppointmentsScreen(
      barberId:    widget.barberId,
      barberName:  widget.barberName,
      barberState: _barberState,
    ),
    BarberStoreScreen(barberId: widget.barberId),
    const SizedBox(), // ← placeholder vacío para el índice 4
  ],
),
    bottomNavigationBar: LiquidGlassBar(
  currentIndex: _selectedIndex,
  barberId:     widget.barberId,
  barberName:   widget.barberName,
  onTap: (index) {
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarberProfileScreen(
            barberId:   widget.barberId,
            barberName: widget.barberName,
            onBack:     () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  },
),
    );
  }

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
          right: 20, bottom: 225,
          child: FloatingActionButton(
            mini: true, backgroundColor: Colors.white, elevation: 4,
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
                  Text("Bienvenido ${widget.barberName}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF242424))),
                  const Text("Selecciona tu disponibilidad",
                    style: TextStyle(color: Color(0xFF242424), fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          ListenableBuilder(
            listenable: _barberState,
            builder: (context, _) {
              return Row(
                children: [
                  Switch(
                    value: _barberState.isAvailable,
                    onChanged: (v) => _barberState.toggleDisponibilidad(
                      v,
                      lat: _currentLatLng?.latitude,
                      lng: _currentLatLng?.longitude,
                    ),
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _barberState.isAvailable ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _barberState.modoTexto,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF242424)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

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

  Widget _buildBarberAvatar() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
        image: _profileImageUrl != null
            ? DecorationImage(
                image: NetworkImage('$baseUrl$_profileImageUrl'), fit: BoxFit.cover)
            : null,
      ),
      child: _profileImageUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
    );
  }
}
