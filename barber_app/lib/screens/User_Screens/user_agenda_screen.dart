import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = "${place.street}, ${place.locality}";
        });
      }
    } catch (e) {
      setState(() => _currentAddress = "Ubicación no disponible");
    }
  }

  Future<void> _fetchFavorites() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/users/${widget.userId}/favorites'),
      );
      if (res.statusCode == 200) {
        final List<dynamic> favs = jsonDecode(res.body);
        setState(() {
          for (var f in favs) {
            _favoritos.add(f['_id'] ?? f['id'] ?? '');
          }
        });
      }
    } catch (e) {
      print("Error favoritos: $e");
    }
  }

  Future<void> _fetchBarbers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/barbers'));
      if (res.statusCode == 200) {
        setState(() {
          barberos = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite(dynamic barbero) async {
    final String barberId = barbero['_id'] ?? barbero['id'] ?? '';
    setState(() {
      if (_favoritos.contains(barberId)) {
        _favoritos.remove(barberId);
      } else {
        _favoritos.add(barberId);
      }
    });
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/barbers/favorite'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': widget.userId, 'barberId': barberId}),
      );
      if (res.statusCode != 200) _fetchFavorites();
    } catch (e) {
      _fetchFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- BOTÓN REGRESAR ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 15, top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            // --- EL TÍTULO ESTILO SLIVER SOLICITADO ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Agendar Cita", // Cambiado para que coincida con el contexto de la screen
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- UBICACIÓN ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.blue[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currentAddress,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- SUBTÍTULO ---
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Text(
                  "Barberos cercanos a ti",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            // --- LISTADO DE BARBEROS ---
            isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildBarberCard(barberos[index]),
                        childCount: barberos.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomMenu(),
    );
  }

  // --- WIDGET AUXILIAR DEL MENÚ ---
  Widget _buildBottomMenu() {
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
            color: Colors.white.withOpacity(0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navAction(
                  Icons.home_filled,
                  "Inicio",
                  false,
                  () => Navigator.pop(context),
                ),
                _navAction(Icons.description, "Servicios", false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserServicesScreen(),
                    ),
                  );
                }),
                _navAction(Icons.storefront, "Tienda", false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UserShopScreen()),
                  );
                }),
                _navAction(Icons.person, "Perfil", false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UserPerfilScreen()),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navAction(
    IconData icon,
    String label,
    bool active,
    VoidCallback tap,
  ) {
    return GestureDetector(
      onTap: tap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? Colors.blue[600] : Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? Colors.blue[600] : Colors.grey[400],
            ),
          ),
        ],
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BarberProfileScreen(barber: b, userId: widget.userId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.person, size: 50, color: Colors.blue[600]),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.payments, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        priceRange,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BookingScreen(barber: b, userId: widget.userId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Agendar",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleFavorite(b),
              icon: Icon(
                isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                color: Colors.blue[700],
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
