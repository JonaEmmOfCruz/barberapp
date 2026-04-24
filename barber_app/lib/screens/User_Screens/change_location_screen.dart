import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';

class ChangeLocationScreen extends StatefulWidget {
  final String initialAddress;
  final LatLng? initialLocation;
  final String? userId;

  const ChangeLocationScreen({
    super.key,
    required this.initialAddress,
    this.initialLocation,
    this.userId,
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

  Future<void> _searchAddressFromText() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final newLatLng = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _currentLatLng = newLatLng;
          _currentAddress = query;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 17));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dirección no encontrada")));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
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
      debugPrint("Error reverse geocoding: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // MAPA
          Positioned.fill(
            child: AppleMap(
              initialCameraPosition: CameraPosition(target: _currentLatLng, zoom: 15),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              onCameraMove: (pos) => _currentLatLng = pos.target,
              onCameraIdle: () => _getAddressFromLatLng(_currentLatLng),
            ),
          ),

          // PIN CENTRAL
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, size: 50, color: Colors.blue[700]),
            ),
          ),

          // HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  _circleBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                  const SizedBox(width: 15),
                  const Text("Ubicación", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
            ),
          ),

          // PANEL DE BÚSQUEDA
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 125),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: "Buscar dirección...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _searchAddressFromText(),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, {'direccion': _currentAddress, 'lat': _currentLatLng.latitude, 'lng': _currentLatLng.longitude}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("CONFIRMAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, size: 18, color: Colors.black), onPressed: onTap),
    );
  }

  Widget _customBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 10))],
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
                colors: [Colors.black.withOpacity(0.2), Colors.white.withOpacity(0.1)],
              ),
              border: Border.all(width: 1.2, color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: _buildNavItem(Icons.home_filled, "Inicio", true),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserServicesScreen())),
                  child: _buildNavItem(Icons.description, "Servicios", false),
                ),
                GestureDetector(
                  onTap: () {
                    if (widget.userId != null) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserReservationsScreen(userId: widget.userId!)));
                    }
                  },
                  child: _buildNavItem(Icons.calendar_month, "Reservas", false),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserPerfilScreen())),
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
      mainAxisAlignment: MainAxisAlignment.center,
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
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}