import 'package:flutter/material.dart';
import 'dart:ui';

class LiquidGlassBar extends StatelessWidget {
  final int currentIndex;
  final String? barberId;
  final String? barberName;
  // Añadimos el callback para avisar al Home del cambio
  final Function(int) onTap; 

  const LiquidGlassBar({
    super.key,
    required this.currentIndex,
    this.barberId,
    this.barberName,
    required this.onTap, // Lo hacemos requerido
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.home_filled, label: "Inicio", index: 0),
                _buildNavItem(icon: Icons.assignment, label: "Servicios", index: 1),
                _buildNavItem(icon: Icons.calendar_month, label: "Agenda", index: 2),
               // _buildNavItem(icon: Icons.store, label: "Tienda", index: 3),
                _buildNavItem(icon: Icons.person, label: "Perfil", index: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    bool isSelected = currentIndex == index;
    // Colores ajustados a tu diseño
    Color activeColor = const Color.fromARGB(143, 124, 124, 124); // Rojo activo
    Color inactiveColor = const Color.fromARGB(255, 255, 36, 36); // Gris inactivo

    return GestureDetector(
      // Simplemente ejecutamos la función que viene del Home
      onTap: () => onTap(index), 
      child: Container(
        color: Colors.transparent, // Para que el click sea más fácil de detectar
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isSelected ? activeColor : inactiveColor, 
              size: 26
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor, 
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              )
            ),
          ],
        ),
      ),
    );
  }
}