import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // <--- AGREGADO PARA EL MENÚ
import 'package:barber_app/config/app_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_app/screens/User_Screens/barber_profile_screen.dart';
import 'package:barber_app/screens/User_Screens/booking_screen.dart';

// Importaciones para las rutas del menú
import 'package:barber_app/screens/User_Screens/user_home_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_shop_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

class UserAgendaScreen extends StatefulWidget {
  final String userId;
  const UserAgendaScreen({super.key, required this.userId});

  @override
  State<UserAgendaScreen> createState() => _UserAgendaScreenState();
}

class _UserAgendaScreenState extends State<UserAgendaScreen> {
  final String baseUrl = AppConfig.baseUrl;
  List<dynamic> barberos = [];
  bool isLoading = true;
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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() { _currentAddress = "${place.street}, ${place.locality}"; });
      }
    } catch (e) {
      setState(() => _currentAddress = "Ubicación no disponible");
    }
  }

  Future<void> _fetchFavorites() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users/${widget.userId}/favorites'));
      if (res.statusCode == 200) {
        final List<dynamic> favs = jsonDecode(res.body);
        setState(() {
          for (var f in favs) { _favoritos.add(f['_id'] ?? f['id'] ?? ''); }
        });
      }
    } catch (e) { print("Error favoritos: $e"); }
  }

  Future<void> _fetchBarbers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/barbers'));
      if (res.statusCode == 200) {
        setState(() {
          barberos = jsonDecode(res.body);
          isLoading = false;
        });
      } else { setState(() => isLoading = false); }
    } catch (e) { setState(() => isLoading = false); }
  }

  Future<void> _toggleFavorite(dynamic barbero) async {
    final String barberId = barbero['_id'] ?? barbero['id'] ?? '';
    final bool isFavorite = _favoritos.contains(barberId);
    setState(() { isFavorite ? _favoritos.remove(barberId) : _favoritos.add(barberId); });
    try {
      final url = Uri.parse('$baseUrl/api/barbers/favorite');
      final body = jsonEncode({'barberId': barberId, 'userId': widget.userId});
      final headers = {'Content-Type': 'application/json'};
      if (isFavorite) { await http.delete(url, headers: headers, body: body); } 
      else { await http.post(url, headers: headers, body: body); }
    } catch (e) {
      setState(() { isFavorite ? _favoritos.add(barberId) : _favoritos.remove(barberId); });
    }
  }

  // --- WIDGET AUXILIAR DEL MENÚ (IDÉNTICO AL HOME) ---
  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: isSelected ? Colors.blue[600] : Colors.grey[400]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue[600] : Colors.grey[400])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _currentAddress,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Barberos cercanos a ti", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Espacio para el menú
                    itemCount: barberos.length,
                    itemBuilder: (context, index) => _buildBarberCard(barberos[index]),
                  ),
          ),
        ],
      ),
      // --- MENÚ INFERIOR AGREGADO SIN MODIFICAR EL RESTO ---
      bottomNavigationBar: Container(
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
                  colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                ),
                border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: _buildNavItem(Icons.home_filled, "Inicio", false),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserServicesScreen()));
                    },
                    child: _buildNavItem(Icons.description, "Servicios", false),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserShopScreen()));
                    },
                    child: _buildNavItem(Icons.storefront, "Tienda", false),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserPerfilScreen()));
                    },
                    child: _buildNavItem(Icons.person, "Perfil", false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarberCard(dynamic b) {
    final String name = b['nombre'] ?? b['name'] ?? 'Barbero';
    final String barberId = b['_id'] ?? b['id'] ?? '';
    final bool isFavorite = _favoritos.contains(barberId);
    final String priceRange = b['precio_base']?.toString() ?? "\$0";
    final String rating = b['rating']?.toString() ?? "0";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => BarberProfileScreen(barber: b, userId: widget.userId)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.person, size: 50, color: Colors.blue[600]),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.payments, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(priceRange, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 15),
                      Icon(Icons.star, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => BookingScreen(barber: b, userId: widget.userId)));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent[400],
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text("Agendar", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleFavorite(b),
              icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_outline, color: Colors.blue[700], size: 30),
            ),
          ],
        ),
      ),
    );
  }
}