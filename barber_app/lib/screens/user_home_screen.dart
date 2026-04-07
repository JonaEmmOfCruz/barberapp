import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/screens/user_perfil_screen.dart';
import 'package:barber_app/config/app_config.dart';

// Ya no necesitamos UserModel porque no haremos la petición a /api/users
// class UserModel { ... }  // ELIMINADO

class UserHomeScreen extends StatefulWidget {
  final String userId;
  final String userName;   // Nuevo parámetro

  const UserHomeScreen({
    super.key, 
    required this.userId,
    required this.userName,   // Recibir el nombre
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  AppleMapController? _mapController;
  LatLng? _currentLatLng;

  final String baseUrl = AppConfig.baseUrl;

  // Eliminamos _user, ya no lo necesitamos
  String _realAddress = "Obteniendo ubicación...";
  bool _isExpanded = false;

  // Lógica de servicios
  String _selectedType = "propio";
  final Set<String> _selectedServices = {};
  final List<Map<String, dynamic>> _finalServiceList = [];

  @override
  void initState() {
    super.initState();
    _initData();  // Solo llamamos a _determinePosition
  }

  Future<void> _initData() async {
    // Eliminamos _fetchUser()
    await _determinePosition();
  }

  // Eliminamos completamente el método _fetchUser()

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
        _realAddress = "${p[0].street}, ${p[0].locality}, ${p[0].administrativeArea}";
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

  // Método para añadir a la lista y limpiar selección
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
      _selectedType = "segundo";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentLatLng == null
              ? const Center(child: CircularProgressIndicator())
              : AppleMap(
                  initialCameraPosition: CameraPosition(target: _currentLatLng!, zoom: 15),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),

          // HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.userName,  // Usamos el nombre recibido
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const Text(
                        "Selecciona el tipo de servicio",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // BOTONES FLOTANTES
          Positioned(
            right: 20,
            top: 130,
            child: Column(
              children: [
                _iconBtn(Icons.person_outline, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserPerfilScreen()),
                  );
                }),
                const SizedBox(height: 12),
                _iconBtn(Icons.my_location, isCircle: true, onTap: _determinePosition),
              ],
            ),
          ),

          // CARD DINÁMICA
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
              ),
              child: _isExpanded ? _buildExpandedBody() : _buildInitialBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: Colors.blue),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tu Ubicación",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    _realAddress,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _blueBtn("Solicitar Servicio", () => setState(() => _isExpanded = true)),
      ],
    );
  }

  Widget _buildExpandedBody() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tipo de servicio:",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                  onPressed: () => setState(() => _isExpanded = false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _typeCard(
                  "Servicio propio",
                  Icons.person,
                  _selectedType == "propio",
                  () => setState(() => _selectedType = "propio"),
                ),
                const SizedBox(width: 12),
                _typeCard(
                  "Servicio a segundo",
                  Icons.group_add,
                  _selectedType == "segundo",
                  () => setState(() => _selectedType = "segundo"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Servicio a solicitar:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _serviceChip("Corte", Icons.content_cut),
                _serviceChip("Barba", Icons.face),
                _serviceChip("Tinte", Icons.color_lens),
                _serviceChip("Combo", Icons.auto_awesome),
                _serviceChip("Cejas", Icons.remove_red_eye_outlined),
              ],
            ),
            const SizedBox(height: 15),

            // BOTÓN AÑADIR SERVICIO
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addServiceAndClear,
                icon: const Icon(Icons.add),
                label: const Text("Añadir servicio"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            if (_finalServiceList.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "Servicios añadidos:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._finalServiceList.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "${index + 1}.",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${item['servicios'].join(", ")} (${item['tipo']})",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => setState(() => _finalServiceList.removeAt(index)),
                      )
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),
            const Text(
              "Ubicación:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              _realAddress,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _blueBtn("Confirmar Servicio", () {
              if (_selectedServices.isNotEmpty) _addServiceAndClear();
              print("ENVIANDO A API: $_finalServiceList");
            }),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES ---

  Widget _typeCard(String text, IconData icon, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.blue[50],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.blue : Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceChip(String text, IconData icon) {
    bool isSelected = _selectedServices.contains(text);
    return GestureDetector(
      onTap: () => setState(() {
        isSelected ? _selectedServices.remove(text) : _selectedServices.add(text);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 8,
              backgroundColor: Colors.white,
              child: Icon(
                icon,
                size: 10,
                color: isSelected ? Colors.blue : Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    // Como ya no tenemos acceso a profileImage sin API, mostramos un ícono
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          color: Colors.blue,
          size: 40,
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
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool isCircle = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Icon(icon, color: Colors.blue, size: 22),
      ),
    );
  }
}