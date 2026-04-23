import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
// IMPORTACIONES NUEVAS PARA UBICACIÓN
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  
  // CAMBIO: Variable para almacenar la dirección real
  String _currentAddress = "Obteniendo ubicación...";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Iniciamos la obtención de ubicación al cargar
    _determinePosition(); 
    await _fetchFavorites();
    await _fetchBarbers();
  }

  // NUEVA FUNCIÓN: Obtiene las coordenadas y las convierte a dirección (Calle, Ciudad)
  Future<void> _determinePosition() async {
    try {
      // 1. Verificar/Solicitar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentAddress = "Permiso denegado");
          return;
        }
      }

      // 2. Obtener posición actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Convertir coordenadas a dirección legible
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // Formato: Calle, Localidad
          _currentAddress = "${place.street}, ${place.locality}";
        });
      }
    } catch (e) {
      setState(() => _currentAddress = "Ubicación no disponible");
      print("Error obteniendo ubicación: $e");
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
      print("Error cargando favoritos iniciales: $e");
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
    final bool isFavorite = _favoritos.contains(barberId);

    setState(() {
      isFavorite ? _favoritos.remove(barberId) : _favoritos.add(barberId);
    });

    try {
      final url = Uri.parse('$baseUrl/api/barbers/favorite');
      final body = jsonEncode({'barberId': barberId, 'userId': widget.userId});
      final headers = {'Content-Type': 'application/json'};

      if (isFavorite) {
        await http.delete(url, headers: headers, body: body);
      } else {
        await http.post(url, headers: headers, body: body);
      }
    } catch (e) {
      setState(() {
        isFavorite ? _favoritos.add(barberId) : _favoritos.remove(barberId);
      });
    }
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
                  // MUESTRA LA DIRECCIÓN REAL ACTUALIZADA
                  Flexible(
                    child: Text(
                      _currentAddress,
                      overflow: TextOverflow.ellipsis, // Por si la dirección es muy larga
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
          const SizedBox(height: 25),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Barberos cercanos a ti",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : barberos.isEmpty
                ? const Center(
                    child: Text(
                      "No hay barberos disponibles en este momento",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: barberos.length,
                    itemBuilder: (context, index) {
                      return _buildBarberCard(barberos[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ... (Resto del código de _buildBarberCard y _confirmar se mantiene igual)
  Widget _buildBarberCard(dynamic b) {
    final String name = b['name'] ?? b['nombre'] ?? 'Barbero sin nombre';
    final String barberId = b['_id'] ?? b['id'] ?? '';
    final bool isFavorite = _favoritos.contains(barberId);

    const String priceRange = "\$0";
    const String rating = "0";
    const String distance = "0 km";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.person, size: 50, color: Colors.blue[600]),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                    Icon(Icons.payments, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    const Text(
                      priceRange,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Icon(Icons.star, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    const Text(
                      rating,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.multiple_stop,
                      size: 14,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      distance,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () => _confirmar(b),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent[400],
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Agendar",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmar(dynamic b) {
    final String name = b['name'] ?? b['nombre'] ?? 'Barbero';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Iniciando proceso para agendar con $name")),
    );
  }
}