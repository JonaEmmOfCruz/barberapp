import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

class ChangeLocationScreen extends StatefulWidget {
  final String initialAddress;
  final LatLng? initialLocation;

  const ChangeLocationScreen({
    super.key,
    required this.initialAddress,
    this.initialLocation,
  });

  @override
  State<ChangeLocationScreen> createState() => _ChangeLocationScreenState();
}

class _ChangeLocationScreenState extends State<ChangeLocationScreen> {
  late String _currentAddress;
  late LatLng _currentLatLng;
  final TextEditingController _addressController = TextEditingController();
  AppleMapController? _mapController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.initialAddress;
    _currentLatLng = widget.initialLocation ?? const LatLng(20.7203, -103.3855);
    _addressController.text = _currentAddress;
  }

  // 1. BUSCAR POR TEXTO (Geocoding)
  Future<void> _searchAddressFromText() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final newLatLng = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );

        setState(() {
          _currentLatLng = newLatLng;
          _currentAddress = query;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 17),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo encontrar esa dirección")),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // 2. OBTENER TEXTO DESDE COORDENADAS (Reverse Geocoding)
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String newAddr = "${place.street}, ${place.locality}";
        setState(() {
          _currentAddress = newAddr;
          _addressController.text = newAddr;
          _currentLatLng = position;
        });
      }
    } catch (e) {
      debugPrint("Error en reverse geocoding: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Vital para el efecto Glassmorphism
      body: Stack(
        children: [
          // MAPA
          Positioned.fill(
            child: AppleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLatLng,
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              onCameraMove: (CameraPosition position) {
                _currentLatLng = position.target;
              },
              onCameraIdle: () {
                _getAddressFromLatLng(_currentLatLng);
              },
            ),
          ),

          // PIN CENTRAL
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, size: 50, color: Colors.blue[800]),
            ),
          ),

          // HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    "Seleccionar Ubicación",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // PANEL DE BÚSQUEDA
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: "Ingresa dirección...",
                      prefixIcon: const Icon(Icons.map_outlined),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, color: Colors.blue),
                              onPressed: _searchAddressFromText,
                            ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'direccion': _currentAddress,
                          'lat': _currentLatLng.latitude,
                          'lng': _currentLatLng.longitude,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "CONFIRMAR ESTA UBICACIÓN",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _customBottomNav(),
    );
  }

  Widget _customBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
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
                  Colors.black.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                width: 1.2,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: _buildNavItem(Icons.home_filled, "Inicio", true),
                ),
                GestureDetector(
                  onTap: () {},
                  child: _buildNavItem(Icons.description, "Servicios", false),
                ),
                GestureDetector(
                  onTap: () {},
                  child: _buildNavItem(Icons.storefront, "Tienda", false),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserPerfilScreen()),
                    );
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

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}