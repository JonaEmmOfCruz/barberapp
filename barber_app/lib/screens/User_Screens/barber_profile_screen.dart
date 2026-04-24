import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:barber_app/screens/User_Screens/booking_screen.dart';
import 'package:barber_app/screens/User_Screens/user_home_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

class BarberProfileScreen extends StatelessWidget {
  final dynamic barber;
  final String userId;

  const BarberProfileScreen({
    super.key,
    required this.barber,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    // Extracción de datos según el modelo de MongoDB
    final String name = barber['nombre'] ?? 'Sin nombre';
    final List<dynamic> servicios = barber['servicios'] ?? [];
    final List<dynamic> diasDisponibles = barber['dias'] ?? [];
    final Map<String, dynamic>? horario = barber['horario'];
    final dynamic vehiculo = barber['vehiculo'];
    final Map<String, dynamic>? redes = barber['redes_sociales'];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // Crucial para el menú flotante
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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),

            // --- TÍTULO ESTILO SLIVER APPLE ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Perfil del Barbero",
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

            // --- CONTENIDO DEL PERFIL ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Header: Avatar y Nombre (Estilo Cards de Reservas)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.person_rounded, size: 50, color: Color(0xFF007AFF)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)),
                              ),
                              Text(
                                servicios.isNotEmpty ? servicios.join(", ") : "Servicios no especificados",
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  const Text("Especialidades y Horarios:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1D1D1F))),
                  const SizedBox(height: 15),
                  
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (diasDisponibles.isNotEmpty)
                        _buildAppleTag(Icons.calendar_month_rounded, "${diasDisponibles.first} - ${diasDisponibles.last}"),
                      if (horario != null)
                        _buildAppleTag(Icons.access_time_filled_rounded, "${horario['apertura']} - ${horario['cierre']}"),
                    ],
                  ),

                  const SizedBox(height: 35),
                  const Text("Galería de trabajos:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1D1D1F))),
                  const SizedBox(height: 10),
                  const Text("Próximamente fotos de los cortes realizados.", style: TextStyle(color: Colors.grey, fontSize: 13)),

                  if (vehiculo != null) ...[
                    const SizedBox(height: 35),
                    const Text("Información del Vehículo:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 15),
                    _buildAppleTag(Icons.directions_car_rounded, "${vehiculo['marca']} • ${vehiculo['matricula']}"),
                  ],

                  const SizedBox(height: 45),
                  // BOTÓN RESERVAR ESTILO APPLE
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(barber: barber, userId: userId))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: const Text("RESERVAR SERVICIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 120), // Espacio para el menú
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _customBottomNav(),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildAppleTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF007AFF)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF1D1D1F), fontWeight: FontWeight.w600)),
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
        boxShadow: [BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 15))],
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
                colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.2)],
              ),
              border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_filled, "Inicio", false, (ctx) => Navigator.pop(ctx)),
                _buildNavItem(Icons.description, "Servicios", false, (ctx) => Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => const UserServicesScreen()))),
                _buildNavItem(Icons.calendar_month, "Reservas", false, (ctx) => Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => UserReservationsScreen(userId: userId)))),
                _buildNavItem(Icons.person, "Perfil", true, (ctx) {}),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, Function(BuildContext) onTap) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => onTap(context),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isSelected ? const Color(0xFF007AFF) : Colors.black.withOpacity(0.3)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF007AFF) : Colors.black.withOpacity(0.3))),
          ],
        ),
      ),
    );
  }
}