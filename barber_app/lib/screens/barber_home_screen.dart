import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/models/user_model.dart';
import 'package:barber_app/config/app_config.dart';

class BarberHomeScreen extends StatefulWidget {
  final String barberId;
  const BarberHomeScreen({super.key, required this.barberId});

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  
  // URL de tu servidor local
  final String baseUrl = AppConfig.baseUrl; 

  UserModel? _barber; // Reutilizamos el modelo, ajustando el nombre
  String _realAddress = "Obteniendo ubicación...";
  bool _isLoading = true;

  // Estado del interruptor de disponibilidad
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchBarberData();
    await _determinePosition();
  }

  // Carga real de los datos del barbero desde MongoDB
  Future<void> _fetchBarberData() async {
    try {
      // Usamos el mismo endpoint de usuario, ya que ambos son 'UserModel' en Mongo
      final response = await http.get(Uri.parse('$baseUrl/api/users/${widget.barberId}'));
      if (response.statusCode == 200) {
        setState(() {
          _barber = UserModel.fromJson(json.decode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Error cargando barbero: $e");
    }
  }

  // GPS Real y Geocoding
  Future<void> _determinePosition() async {
    setState(() => _isLoading = true);
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _realAddress = "Permiso de ubicación denegado";
          _isLoading = false;
        });
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _currentLatLng = LatLng(position.latitude, position.longitude);
      
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      
      setState(() {
        _realAddress = "${place.street}, ${place.locality}, ${place.administrativeArea}";
        _isLoading = false;
      });

      // Centrar el mapa automáticamente con zoom pro
      _centerMapWithZoom();
    } catch (e) {
      // Fallback a Zapopan si falla el GPS
      setState(() {
        _currentLatLng = const LatLng(20.7219, -103.3911); // Zapopan, Jal
        _realAddress = "C. Calle #1, Zapopan, Jalisco (GPS falló)";
        _isLoading = false;
      });
      _centerMapWithZoom();
    }
  }

  // MÉTODO PARA CENTRAR CON ZOOM EXTRA (reutilizado)
  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLatLng!,
            zoom: 17.5, // Zoom pro para ver calles
          ),
        ),
      );
    }
  }

  // Método para actualizar disponibilidad en MongoDB (Placeholder)
  Future<void> _updateAvailability(bool value) async {
    // Simulación de actualización de estado
    setState(() => _isAvailable = value);
    
    /* Lógica real para tu backend:
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/${widget.barberId}/availability'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'isActive': value}),
      );
      if (response.statusCode != 200) {
        // Revertir estado si falla
        setState(() => _isAvailable = !value);
        debugPrint("Falla al actualizar disponibilidad");
      }
    } catch (e) {
      setState(() => _isAvailable = !value);
      debugPrint("Error de red: $e");
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. MAPA DE FONDO
          _currentLatLng == null 
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : AppleMap(
                initialCameraPosition: CameraPosition(target: _currentLatLng!, zoom: 16),
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // Desactivado por diseño
                compassEnabled: false,
              ),

          // 2. CAPA DE INTERFAZ (SafeArea para no tapar barra de estado)
          SafeArea(
            child: Column(
              children: [
                // --- HEADER SUPERIOR Reutilizado ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                  child: Row(
                    children: [
                      _buildBarberAvatar(),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Bienvenido ${_barber?.nombre ?? 'Barbero'}", 
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            const Text("Tu estado actual", 
                              style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(), // Empuja todo hacia abajo
                
                // --- PANEL INFERIOR MODIFICADO PARA BARBERO (Captura 3) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96), // Fondo ligeramente transparente
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 2)
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sección Ubicación (reutilizada)
                        Row(
                          children: [
                            Container(
                              width: 55, height: 55,
                              decoration: BoxDecoration(
                                color: Colors.blue[50], 
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: const Icon(Icons.location_on, color: Colors.blue, size: 28),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tu Ubicación actual", 
                                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  _isLoading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,))
                                    : Text(_realAddress, 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3),
                                        maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 25), // Separación
                        const Divider(color: Colors.grey, height: 1), // Línea separadora sutil
                        const SizedBox(height: 15), // Separación
                        
                        // --- NUEVA SECCIÓN: CONTROL DE DISPONIBILIDAD ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isAvailable ? "Disponible:" : "No Disponible:", 
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: _isAvailable ? Colors.blue : Colors.blueGrey, // Color dinámico
                              )
                            ),
                            // Interruptor estilizado (iOS style)
                            Transform.scale(
                              scale: 0.9, // Un poco más pequeño
                              child: Switch(
                                value: _isAvailable,
                                onChanged: _updateAvailability,
                                activeColor: Colors.white, // Color del círculo interior activo
                                activeTrackColor: Colors.blue, // Color de la pista activa
                                inactiveThumbColor: Colors.white, // Color del círculo interior inactivo
                                inactiveTrackColor: Colors.grey[400], // Color de la pista inactiva
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Diseño compacto
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 25), // Margen inferior final
              ],
            ),
          ),

          // 3. BOTONES FLOTANTES AZULES DERECHOS (reutilizados)
          Positioned(
            right: 20,
            top: 130, // Justo debajo del header
            child: Column(
              children: [
                _iconBtn(Icons.assignment_turned_in_outlined, () {
                  // Navegar a lista de citas/servicios
                  debugPrint("Ver Citas");
                }, isCircle: false),
                const SizedBox(height: 12),
                _iconBtn(Icons.my_location, _centerMapWithZoom, isCircle: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES AUXILIARES ---

  Widget _buildBarberAvatar() {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: (_barber?.profileImage != null)
            ? Image.network('$baseUrl${_barber!.profileImage}', fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.cut, size: 35, color: Colors.blue)) // Icono de tijeras para barbero
            : const Icon(Icons.cut, size: 35, color: Colors.blue),
      ),
    );
  }

  // Botón flotante genérico (reutilizado)
  Widget _iconBtn(IconData icon, VoidCallback onTap, {required bool isCircle}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.15), blurRadius: 8, spreadRadius: 1)],
        ),
        child: Icon(icon, color: Colors.blue, size: 24),
      ),
    );
  }
}