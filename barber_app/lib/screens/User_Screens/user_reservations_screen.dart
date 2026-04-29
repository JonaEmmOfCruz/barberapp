import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/User_Screens/user_home_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

class UserReservationsScreen extends StatefulWidget {
  final String userId;
  const UserReservationsScreen({super.key, required this.userId});

  @override
  State<UserReservationsScreen> createState() => _UserReservationsScreenState();
}

class _UserReservationsScreenState extends State<UserReservationsScreen> {
  final String baseUrl = AppConfig.baseUrl;
  List<dynamic> reservations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReservations();
  }

  Future<void> _fetchReservations() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/reservas/user/${widget.userId}'),
      );

      if (res.statusCode == 200) {
        final decodedData = jsonDecode(res.body);
        setState(() {
          reservations = decodedData is List ? decodedData : (decodedData['reservas'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo limpio
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
            : RefreshIndicator(
                onRefresh: _fetchReservations,
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
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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
                              "Mis Reservas",
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

                    // --- LISTADO DE RESERVAS CON DISEÑO DE CARDS ACTUALIZADO ---
                    reservations.isEmpty
                        ? const SliverFillRemaining(
                            child: Center(
                              child: Text("No tienes servicios agendados", style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildModernReservationCard(reservations[index]),
                                childCount: reservations.length,
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

  // Card con el diseño solicitado (Gris suave y avatar blanco)
  Widget _buildModernReservationCard(dynamic res) {
    final barberData = res['barberId'];
    String nombre = "Barbero";
    if (barberData is Map) {
      nombre = barberData['nombre'] ?? barberData['name'] ?? "Barbero";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7), // Gris claro estilo iOS
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
            child: const Icon(Icons.person_rounded, size: 45, color: Color(0xFF007AFF)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1D1D1F)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF007AFF)),
                    const SizedBox(width: 4),
                    Text(
                      res['fecha']?.toString().split('T')[0] ?? "Sin fecha",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF007AFF)),
                    const SizedBox(width: 4),
                    Text(
                      res['hora'] ?? "00:00",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  // Menú Flotante Visible (Glassmorphism Claro)
  Widget _customBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_filled, "Inicio", false, () => Navigator.pop(context)),
                _buildNavItem(Icons.description, "Servicios", false, () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserServicesScreen()));
                }),
                _buildNavItem(Icons.calendar_month, "Reservas", true, () {}),
                _buildNavItem(Icons.person, "Perfil", false, () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserPerfilScreen()));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, VoidCallback onTap) {
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