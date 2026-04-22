import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
// Asegúrate de importar la pantalla de mapa para el retroceso si es necesario, 
// aunque Navigator.pop suele ser suficiente.
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
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.initialAddress;
  }

  // Widget para los items del menú inferior
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
      // Permite que el mapa se extienda detrás de la barra de navegación
      extendBody: true,
      body: Stack(
        children: [
          // 1. MAPA OCUPANDO TODO EL FONDO
          Positioned.fill(
            child: AppleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initialLocation ?? const LatLng(20.7203, -103.3855),
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),

          // 2. HEADER (Flecha de regreso + Usuario con redirección)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              child: Row(
                children: [
                  // FLECHA DE REGRESO
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 5),
                  // CONTENEDOR DE USUARIO
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserPerfilScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ],
                      ),
                      child: Icon(Icons.person, color: Colors.blue[700], size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Usuario",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Ingresa tu dirección",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. BOTÓN PARA CENTRAR UBICACIÓN
          Positioned(
            right: 20,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              width: 45,
              height: 45,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Icon(Icons.my_location, color: Colors.blue[600], size: 22),
            ),
          ),

          // 4. WIDGET DE UBICACIÓN (Separado del menú inferior)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 110, left: 20, right: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ubicación:",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentAddress,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: "Nueva dirección...",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _addressController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "CONFIRMAR",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 5. MENÚ INFERIOR FLOTANTE PERSONALIZADO
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.home_filled, "Inicio", true),
            _buildNavItem(Icons.description, "Servicios", false),
            _buildNavItem(Icons.storefront, "Tienda", false),
            _buildNavItem(Icons.person, "Perfil", false),
          ],
        ),
      ),
    );
  }
}