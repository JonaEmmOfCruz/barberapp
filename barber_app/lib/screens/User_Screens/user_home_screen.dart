import 'dart:io';
import 'dart:ui';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:barber_app/screens/User_Screens/user_map_screen.dart';
import 'package:barber_app/screens/User_Screens/user_agenda_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/config/app_config.dart';

class UserHomeScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserHomeScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String? profileImageUrl;
  final String baseUrl = AppConfig.baseUrl;
  String _realAddress = "Obteniendo ubicación...";

  // Lista exclusiva para los favoritos
  List<dynamic> barberosFavoritos = [];
  bool _isLoadingBarbers = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserPhoto();
    await _handleLocationLogic();
    await _fetchBarberosFavoritos(); // Llamamos a la nueva función
  }

  // --- NUEVA LÓGICA: Obtener solo favoritos ---
  Future<void> _fetchBarberosFavoritos() async {
    try {
      // 👇 NUEVA URL: Busca en la colección de barberos
      final res = await http.get(
        Uri.parse('$baseUrl/api/barbers/favorites/${widget.userId}'),
      );

      if (res.statusCode == 200) {
        setState(() {
          barberosFavoritos = jsonDecode(res.body);
          _isLoadingBarbers = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingBarbers = false);
    }
  }

  Future<void> _handleLocationLogic() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    bool isSimulator = false;
    try {
      if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        isSimulator = !iosInfo.isPhysicalDevice;
      } else if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        isSimulator = !androidInfo.isPhysicalDevice;
      }
    } catch (e) {
      isSimulator = false;
    }

    if (isSimulator) {
      setState(() => _realAddress = "C. Falsa #123, Zapopan (Simulador)");
    } else {
      await _determineRealPosition();
    }
  }

  Future<void> _determineRealPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Verificar si el GPS del celular está encendido
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _realAddress = "Por favor activa tu GPS");
        return;
      }

      // 2. Verificar el estado de los permisos
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // AQUÍ es donde el iPhone mostrará el mensaje del Info.plist
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _realAddress = "Permiso de ubicación denegado");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _realAddress = "Habilita la ubicación en Ajustes");
        return;
      }

      // 3. Si todo está bien, obtenemos la posición
      // Nota: A veces 'high' tarda mucho en interiores, puedes usar 'medium' para pruebas rápidas
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Convertir coordenadas a dirección (Geocoding)
      List<Placemark> p = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (p.isNotEmpty) {
        Placemark place = p[0];
        setState(() {
          _realAddress = "${place.street}, ${place.locality}";
        });
      }
    } catch (e) {
      print("Error detallado: $e");
      setState(() => _realAddress = "Error al obtener ubicación");
    }
  }

  Future<void> _loadUserPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => profileImageUrl = prefs.getString('profileImage'));
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserMapScreen(userId: widget.userId, userName: widget.userName),
      ),
    );
  }

  // Cambiamos a Future<void> y agregamos async/await
  Future<void> _navigateToAgenda() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserAgendaScreen(userId: widget.userId),
      ),
    );

    // 🚨 ESTO ES CLAVE: Al regresar de la agenda, recargamos los favoritos
    setState(() {
      _isLoadingBarbers = true;
    });
    _fetchBarberosFavoritos();
  }

  // Widget auxiliar para los items del menú inferior
  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: isSelected ? Colors.blue[600] : Colors.grey[400],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue[600] : Colors.grey[400],
          ),
        ),
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
        title: Text(
          "Bienvenido ${widget.userName}",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTopAction(
                    Icons.location_on,
                    "Servicio",
                    onTap: _navigateToMap,
                  ),
                  _buildTopAction(
                    Icons.calendar_month,
                    "Agendar",
                    onTap: _navigateToAgenda,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            _buildLocationCard(),

            const SizedBox(height: 30),

            // Título restaurado
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Barberos Favoritos",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 15),

            // Condicional restaurado
            _isLoadingBarbers
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: barberosFavoritos.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "Aún no tienes barberos favoritos",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: barberosFavoritos
                                .map((b) => _buildBarberCard(b))
                                .toList(),
                          ),
                  ),
            const SizedBox(height: 100), // Espacio extra para el menú flotante
          ],
        ),
      ),
      // --- MENU INFERIOR ---
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
                  GestureDetector(
                    onTap: () => /* Ya estás en Inicio */ {},
                    child: _buildNavItem(Icons.home_filled, "Inicio", true),
                  ),
                  // --- BOTÓN SERVICIOS ACTUALIZADO ---
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserServicesScreen(),
                        ),
                      );
                    },
                    child: _buildNavItem(Icons.description, "Servicios", false),
                  ),
                  // ----------------------------------
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserShopScreen(),
                        ),
                      );
                    },
                    child: _buildNavItem(Icons.storefront, "Tienda", false),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserPerfilScreen(),
                        ),
                      );
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

  Widget _buildLocationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 30),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToMap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "SOLICITAR SERVICIO",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAction(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue, size: 40),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBarberCard(dynamic b) {
    final String barberName = b['name'] ?? b['nombre'] ?? 'Barbero';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: b['photo'] != null
                ? NetworkImage('$baseUrl${b['photo']}')
                : null,
            child: b['photo'] == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 15),
          Text(barberName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton(
            onPressed: _navigateToAgenda,
            child: const Text("Agendar"),
          ),
        ],
      ),
    );
  }
}
