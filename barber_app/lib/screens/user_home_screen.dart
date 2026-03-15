import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelo de MongoDB
class UserModel {
  final String id;
  final String nombre;
  final String? profileImage;

  UserModel({required this.id, required this.nombre, this.profileImage});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? 'Usuario',
      profileImage: json['profileImage'],
    );
  }
}

class UserHomeScreen extends StatefulWidget {
  final String userId;
  const UserHomeScreen({super.key, required this.userId});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  
  final String baseUrl = 'http://192.168.100.4:3000'; 

  UserModel? _user;
  String _realAddress = "Obteniendo ubicación...";
  bool _isExpanded = false;
  int _serviceCount = 1;
  String _selectedType = "propio"; 
  final Set<String> _selectedServices = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchUser();
    await _determinePosition();
  }

  Future<void> _fetchUser() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/users/${widget.userId}'));
      if (response.statusCode == 200) {
        setState(() => _user = UserModel.fromJson(json.decode(response.body)));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _currentLatLng = LatLng(position.latitude, position.longitude);
      
      List<Placemark> p = await placemarkFromCoordinates(position.latitude, position.longitude);
      setState(() {
        _realAddress = "${p[0].street}, ${p[0].locality}, ${p[0].administrativeArea}";
      });
      
      // Llamamos a centrar con el nuevo zoom
      _centerMapWithZoom();
    } catch (e) {
      setState(() => _realAddress = "C. Calle #1, Zapopan, Jalisco");
    }
  }

  // MÉTODO PARA CENTRAR CON ZOOM EXTRA
  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLatLng!,
            zoom: 18.0, // Ajusta este valor (15 es normal, 18 es más cerca)
          ),
        ),
      );
    }
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
                      Text(_user?.nombre ?? "User", 
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const Text("Selecciona el tipo de servicio", 
                        style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w600)),
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
                _iconBtn(Icons.person_outline, isCircle: false),
                const SizedBox(height: 12),
                // Botón de ubicación con zoom mejorado
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
            Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.location_on, color: Colors.blue)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Tu Ubicación", style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text(_realAddress, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ])),
          ],
        ),
        const SizedBox(height: 20),
        _blueBtn("SOLICITAR SERVICIO", () => setState(() => _isExpanded = true)),
      ],
    );
  }

  Widget _buildExpandedBody() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Tipo de servicio:", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue), onPressed: () => setState(() => _isExpanded = false)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _typeCard("Servicio propio", Icons.person, _selectedType == "propio", () => setState(() => _selectedType = "propio")),
            const SizedBox(width: 12),
            _typeCard("Servicio a segundo", Icons.group_add, _selectedType == "segundo", () => setState(() => _selectedType = "segundo")),
          ]),
          const SizedBox(height: 20),
          const Text("Servicios a solicitar:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _serviceChip("Corte", Icons.content_cut),
            _serviceChip("Barba", Icons.face),
            _serviceChip("Tinte", Icons.color_lens),
            _serviceChip("Combo", Icons.auto_awesome),
            _serviceChip("Cejas", Icons.remove_red_eye_outlined),
          ]),
          const SizedBox(height: 20),
          const Text("Cantidad de servicios:", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _qtyBtn(Icons.remove, () => setState(() => _serviceCount > 1 ? _serviceCount-- : null)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text("$_serviceCount", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            _qtyBtn(Icons.add, () => setState(() => _serviceCount++)),
          ]),
          const SizedBox(height: 20),
          const Text("Ubicación:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(_realAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          _blueBtn("CONFIRMAR SERVICIO", () {
            print("Servicios: $_selectedServices");
          }),
        ],
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
          child: Column(children: [
            CircleAvatar(
              radius: 14, 
              backgroundColor: Colors.white, 
              child: Icon(icon, size: 16, color: selected ? Colors.blue : Colors.blueAccent)
            ),
            const SizedBox(height: 10),
            Text(text, style: TextStyle(color: selected ? Colors.white : Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _serviceChip(String text, IconData icon) {
    bool isSelected = _selectedServices.contains(text);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? _selectedServices.remove(text) : _selectedServices.add(text)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 8, 
            backgroundColor: Colors.white, 
            child: Icon(icon, size: 10, color: isSelected ? Colors.blue : Colors.blueAccent)
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: isSelected ? Colors.white : Colors.blue, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 65, height: 65,
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(15)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: _user?.profileImage != null
            ? Image.network('$baseUrl${_user!.profileImage}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.blue))
            : const Icon(Icons.person, color: Colors.blue),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.blue)),
    );
  }

  Widget _blueBtn(String text, VoidCallback onTap) {
    return SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ));
  }

  Widget _iconBtn(IconData icon, {bool isCircle = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(color: Colors.white, shape: isCircle ? BoxShape.circle : BoxShape.rectangle, borderRadius: isCircle ? null : BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: Icon(icon, color: Colors.blue, size: 22),
      ),
    );
  }
}