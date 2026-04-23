import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; 
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

  // 1. BUSCAR POR TEXTO (Geocoding)
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

        // Movemos la cámara a la ubicación encontrada
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 17), // Zoom más cercano para precisión
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo encontrar esa dirección")),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // 2. OBTENER TEXTO DESDE COORDENADAS (Reverse Geocoding)
  // Se llama cuando el usuario deja de mover el mapa
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Formateamos una dirección legible
        String newAddr = "${place.street}, ${place.locality}";
        setState(() {
          _currentAddress = newAddr;
          _addressController.text = newAddr;
          _currentLatLng = position;
        });
      }
    } catch (e) {
      debugPrint("Error en reverse geocoding: $e");
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
              initialCameraPosition: CameraPosition(
                target: _currentLatLng,
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              // Detectamos cuando la cámara se mueve
              onCameraMove: (CameraPosition position) {
                _currentLatLng = position.target;
              },
              // Cuando el usuario suelta el mapa, actualizamos la dirección de texto
              onCameraIdle: () {
                _getAddressFromLatLng(_currentLatLng);
              },
            ),
          ),

          // PIN DE UBICACIÓN CENTRAL (ESTÁTICO)
          // Este es el "Icono de location" que el usuario usa para apuntar
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40), // Ajuste para que la punta del pin sea el centro
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Colors.blue[800],
              ),
            ),
          ),

          // HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    "Seleccionar Ubicación",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // PANEL DE BÚSQUEDA Y CONFIRMACIÓN
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Buscador de dirección
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: "Ingresa dirección (Calle, ciudad...)",
                      prefixIcon: const Icon(Icons.map_outlined),
                      suffixIcon: _isSearching 
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.search, color: Colors.blue),
                            onPressed: _searchAddressFromText,
                          ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botón de Confirmación
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        // Devolvemos el objeto exacto que requiere tu backend/ServiceRequest
                        Navigator.pop(context, {
                          'direccion': _currentAddress,
                          'lat': _currentLatLng.latitude,
                          'lng': _currentLatLng.longitude,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "CONFIRMAR ESTA UBICACIÓN",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
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

  Widget _customBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
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
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: isSelected ? Colors.blue[600] : Colors.grey[400]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.blue[600] : Colors.grey[400])),
      ],
    );
  }
}