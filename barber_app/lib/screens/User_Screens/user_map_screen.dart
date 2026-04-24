import 'dart:ui';

import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/screens/Main_Screens/waiting_screen.dart';
import 'package:barber_app/screens/User_Screens/change_location_screen.dart';

class UserMapScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserMapScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserMapScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserMapScreen> {
  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  String? profileImageUrl;

  final String baseUrl = AppConfig.baseUrl;

  String _realAddress = "Obteniendo ubicación...";
  bool _isExpanded = false;
  bool _isLoadingService = false;

  final String _selectedType = "propio";
  final Set<String> _selectedServices = {};
  final List<Map<String, dynamic>> _finalServiceList = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserPhoto();
    await _determinePosition();
  }

  Future<void> _loadUserPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profileImageUrl = prefs.getString('profileImage');
    });
  }

  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(position.latitude, position.longitude);

      List<Placemark> p = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _realAddress =
            "${p[0].street}, ${p[0].locality}, ${p[0].administrativeArea}";
      });
      _centerMapWithZoom();
    } catch (e) {
      setState(() => _realAddress = "C. Calle #1, Zapopan, Jalisco");
    }
  }

  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLatLng!, zoom: 18.0),
        ),
      );
    }
  }

  void _addServiceAndClear() {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un servicio")),
      );
      return;
    }

    setState(() {
      _finalServiceList.add({
        'tipo': _selectedType,
        'servicios': _selectedServices.toList(),
        'costo_estimado': null,
      });
      _selectedServices.clear();
    });
  }

  Future<void> _confirmarServicio() async {
    if (_selectedServices.isNotEmpty) {
      _addServiceAndClear();
    }

    if (_finalServiceList.isEmpty) {
      _showError("Añade al menos un servicio");
      return;
    }

    final primerGrupo = _finalServiceList.first;
    final tipo = primerGrupo['tipo'] as String?;
    final servicios = primerGrupo['servicios'] as List<String>?;

    if (tipo == null || tipo.isEmpty) {
      _showError("El tipo de servicio no es válido");
      return;
    }
    if (servicios == null || servicios.isEmpty) {
      _showError("No hay servicios seleccionados");
      return;
    }

    final lat = _currentLatLng?.latitude;
    final lng = _currentLatLng?.longitude;

    if (lat == null || lng == null) {
      _showError("Ubicación no disponible. Intenta de nuevo.");
      return;
    }

    final body = jsonEncode({
      'userId': widget.userId,
      'tipo': tipo,
      'servicios': servicios,
      'ubicacion': {
        'direccion': _realAddress,
        'coordenadas': {'lat': lat, 'lng': lng},
      },
    });

    setState(() {
      _isLoadingService = true;
      _isExpanded = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/service-requests'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      setState(() {
        _isLoadingService = false;
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final serviceId =
            data['ServiceRequestId']?.toString() ?? data['id']?.toString();

        if (serviceId == null) {
          _showError("Error al procesar la respuesta del servidor");
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingScreen(serviceRequestId: serviceId),
          ),
        );
      } else {
        _showError("Error al crear la solicitud");
      }
    } catch (e) {
      setState(() => _isLoadingService = false);
      _showError("Error de conexión");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _currentLatLng == null
              ? const Center(child: CircularProgressIndicator())
              : AppleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 15,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),

          // Header de Usuario
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  _buildAvatar(),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Selecciona el tipo de servicio",
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botones Flotantes
          Positioned(
            right: 20,
            top: 130,
            child: Column(
              children: [
                _iconBtn(
                  Icons.person_outline,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserPerfilScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _iconBtn(
                  Icons.my_location,
                  isCircle: true,
                  onTap: _determinePosition,
                ),
              ],
            ),
          ),

          // Panel Inferior
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 20),
                ],
              ),
              child: _isLoadingService
                  ? _buildLoadingBody()
                  : (_isExpanded ? _buildExpandedBody() : _buildInitialBody()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _customBottomNav(),
    );
  }

  Widget _buildInitialBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _locationIconBox(),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tu Ubicación",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    _realAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _blueBtn(
          "SOLICITAR SERVICIO",
          () => setState(() => _isExpanded = true),
        ),
      ],
    );
  }

  Widget _buildExpandedBody() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Servicios:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isExpanded = false),
              ),
            ],
          ),
          _servicesGrid(),
          const SizedBox(height: 15),

          // BOTÓN AÑADIR SERVICIO
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: _addServiceAndClear,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("AÑADIR A LA LISTA"),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.blue[600]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // LISTA DE SERVICIOS AÑADIDOS
          if (_finalServiceList.isNotEmpty) ...[
            const SizedBox(height: 15),
            const Text(
              "Servicios añadidos:",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._finalServiceList.asMap().entries.map((entry) {
              int idx = entry.key;
              List<String> svs = List<String>.from(entry.value['servicios']);
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        svs.join(", "),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _finalServiceList.removeAt(idx)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],

          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ubicación:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeLocationScreen(
                        initialAddress: _realAddress,
                        initialLocation: _currentLatLng,
                      ),
                    ),
                  );

                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      _realAddress = result['direccion'];
                      _currentLatLng = LatLng(result['lat'], result['lng']);
                    });
                    _centerMapWithZoom();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "Cambiar ubicación",
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _realAddress,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 30),
          _blueBtn("CONFIRMAR SERVICIO", _confirmarServicio),
        ],
      ),
    );
  }

  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _locationIconBox(icon: Icons.search),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Buscando barbero",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    "Espera un momento...",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        const CircularProgressIndicator(),
        const SizedBox(height: 25),
        _blueBtn("CANCELAR", () => setState(() => _isLoadingService = false)),
      ],
    );
  }

  Widget _locationIconBox({IconData icon = Icons.location_on}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.blue),
    );
  }

  Widget _servicesGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _newServiceChip("Corte", Icons.content_cut)),
            const SizedBox(width: 10),
            Expanded(child: _newServiceChip("Barba", Icons.face)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _newServiceChip("Ceja", Icons.remove_red_eye)),
            const SizedBox(width: 10),
            Expanded(child: _newServiceChip("Greka", Icons.design_services)),
          ],
        ),
      ],
    );
  }

  Widget _newServiceChip(String text, IconData icon) {
    bool isSelected = _selectedServices.contains(text);
    return GestureDetector(
      onTap: () => setState(
        () => isSelected
            ? _selectedServices.remove(text)
            : _selectedServices.add(text),
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.blue[400],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blueBtn(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool isCircle = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Icon(icon, color: Colors.blue[700], size: 22),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserPerfilScreen()),
      ).then((_) => _loadUserPhoto()),
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(15),
          image: profileImageUrl != null
              ? DecorationImage(
                  image: NetworkImage('$baseUrl$profileImageUrl'),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: profileImageUrl == null
            ? Icon(Icons.person, color: Colors.blue[700])
            : null,
      ),
    );
  }

  // Sustituye tu método _customBottomNav por este:
  Widget _customBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[900]!.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                width: 1.5,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // INICIO (Actual)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = false;
                    });
                    _centerMapWithZoom();
                  },
                  child: _buildNavItem(Icons.home_filled, "Inicio", true),
                ),

                // SERVICIOS
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const UserServicesScreen(), // Asegúrate de tener este import
                    ),
                  ),
                  child: _buildNavItem(Icons.description, "Servicios", false),
                ),

                // RESERVAS
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserReservationsScreen(userId: widget.userId),
                    ),
                  ),
                  child: _buildNavItem(Icons.calendar_month, "Reservas", false),
                ),

                /* --- TIENDA COMENTADA ---
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserShopScreen()),
                  ),
                  child: _buildNavItem(Icons.storefront, "Tienda", false),
                ),
                ------------------------ */

                // PERFIL
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserPerfilScreen(),
                      ),
                    ).then((_) => _loadUserPhoto());
                  },
                  child: _buildNavItem(Icons.person, "Perfil", false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Sustituye tu _buildNavItem por este (para que los colores coincidan con el resto de la app):
  

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          // Blanco puro si está seleccionado, blanco traslúcido si no
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
