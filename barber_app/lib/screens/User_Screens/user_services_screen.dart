import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:barber_app/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importaciones de tus pantallas
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';

class UserServicesScreen extends StatefulWidget {
  const UserServicesScreen({super.key});

  @override
  State<UserServicesScreen> createState() => _UserServicesScreenState();
}

class _UserServicesScreenState extends State<UserServicesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;
  String? _userId;
  final String baseUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserServices();
  }

  Future<void> _fetchUserServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');

      if (_userId == null || _userId!.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final String url = '$baseUrl/api/service-requests/user/$_userId';
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchUserServices,
                color: const Color(0xFF007AFF),
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

                    // --- TÍTULO ESTILO SLIVER ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Mis servicios",
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

                    // --- LISTADO DE SERVICIOS ---
                    _services.isEmpty
                        ? const SliverFillRemaining(
                            child: Center(
                              child: Text(
                                "No tienes servicios solicitados",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildServiceCard(_services[index]),
                                childCount: _services.length,
                              ),
                            ),
                          ),

                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _customBottomNav(),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final String barberName =
        service['barbero_nombre'] ?? service['barberName'] ?? "No asignado";
    final dynamic rawServicios = service['servicios'];
    String serviciosTexto = (rawServicios is List)
        ? rawServicios.join(", ")
        : (rawServicios ?? "Sin servicios");

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 45,
              color: Color(0xFF007AFF),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barberName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                Text(
                  serviciosTexto,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      size: 14,
                      color: Color(0xFF007AFF),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "\$0.00",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time_filled_rounded,
                      size: 14,
                      color: Color(0xFF007AFF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service['status'] ?? "Pendiente",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
            // Sombra azul clara para que resalte sobre el blanco
            color: const Color(0xFF007AFF).withOpacity(0.12),
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
              // Gradiente de blanco traslúcido para el efecto Glassmorphism claro
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                width: 1.5,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  Icons.home_filled,
                  "Inicio",
                  false,
                  () => Navigator.pop(context),
                ),
                _buildNavItem(Icons.description, "Servicios", true, () {}),
                _buildNavItem(Icons.calendar_month, "Reservas", false, () {
                  if (_userId != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserReservationsScreen(userId: _userId!),
                      ),
                    );
                  }
                }),
                _buildNavItem(
                  Icons.person,
                  "Perfil",
                  false,
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UserPerfilScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            // Azul para el seleccionado, gris suave para el inactivo
            color: isSelected ? const Color(0xFF007AFF) : Colors.black.withOpacity(0.3),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF007AFF) : Colors.black.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
