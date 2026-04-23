import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Necesario para BackdropFilter e ImageFilter
import 'package:barber_app/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importaciones de tus pantallas para el menú
import 'package:barber_app/screens/User_Screens/user_home_screen.dart';
import 'package:barber_app/screens/User_Screens/user_shop_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

class UserServicesScreen extends StatefulWidget {
  const UserServicesScreen({super.key});

  @override
  State<UserServicesScreen> createState() => _UserServicesScreenState();
}

class _UserServicesScreenState extends State<UserServicesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;
  final String baseUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserServices();
  }

  Future<void> _fetchUserServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final String url = '$baseUrl/api/service-requests/user/$userId';
      print("Consultando: $url");

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _services = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error en la petición: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- FUNCIÓN AUXILIAR DEL MENÚ ---
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mis servicios",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUserServices,
              child: _services.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Center(child: Text("No tienes servicios solicitados")),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Padding inferior para el menú flotante
                      itemCount: _services.length,
                      itemBuilder: (context, index) {
                        final service = _services[index];
                        return _buildServiceCard(service);
                      },
                    ),
            ),
      // --- COPIA EXACTA DEL MENÚ DE USER_HOME_SCREEN ---
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
                    onTap: () {
                      // Al ser el menú principal, usamos pushReplacement para no acumular pantallas
                      Navigator.pop(context);
                    },
                    child: _buildNavItem(Icons.home_filled, "Inicio", false),
                  ),
                  GestureDetector(
                    onTap: () => /* Ya estás aquí */ {},
                    child: _buildNavItem(Icons.description, "Servicios", true),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const UserShopScreen()),
                      );
                    },
                    child: _buildNavItem(Icons.storefront, "Tienda", false),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
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
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final String barberName = service['barbero_nombre'] ?? 
                             service['barberName'] ?? 
                             "No asignado";

    final dynamic rawServicios = service['servicios'];
    String serviciosTexto = "Sin servicios especificados";

    if (rawServicios is List) {
      serviciosTexto = rawServicios.join(", ");
    } else if (rawServicios is String) {
      serviciosTexto = rawServicios;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFC5D9F9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.person, size: 45, color: Color(0xFF2962FF)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barberName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  serviciosTexto,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.payments, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text("\$0.00", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(width: 20),
                    Icon(Icons.access_time_filled, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text("0 min", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}