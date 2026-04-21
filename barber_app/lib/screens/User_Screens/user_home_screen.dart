import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/screens/Main_Screens/waiting_screen.dart';

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
  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  String? profileImageUrl;

  final String baseUrl = AppConfig.baseUrl;

  String _realAddress = "Obteniendo ubicación...";
  bool _isExpanded = false;
  bool _isLoadingService =
      false; // <-- NUEVO: controla la vista de carga en la tarjeta

  // Lógica de servicios
  String _selectedType = "propio";
  final Set<String> _selectedServices = {};
  final List<Map<String, dynamic>> _finalServiceList = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadUserPhoto();
    await _determinePosition();
  }

  Future<void> _loadUserPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profileImageUrl = prefs.getString('profileImage');
    });
  }

  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(position.latitude, position.longitude);

      List<Placemark> p = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _realAddress =
            "${p[0].street}, ${p[0].locality}, ${p[0].administrativeArea}";
      });
      _centerMapWithZoom();
    } catch (e) {
      setState(() => _realAddress = "C. Calle #1, Zapopan, Jalisco");
    }
  }

  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLatLng!, zoom: 18.0),
        ),
      );
    }
  }

  void _addServiceAndClear() {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un servicio")),
      );
      return;
    }

    setState(() {
      _finalServiceList.add({
        'tipo': _selectedType,
        'servicios': _selectedServices.toList(),
        'costo_estimado': null,
      });
      _selectedServices.clear();
      _selectedType = "segundo";
    });
  }

  // -------------------------------------------------------------
  // MÉTODO PRINCIPAL DE CONFIRMACIÓN (MODIFICADO)
  // -------------------------------------------------------------
  Future<void> _confirmarServicio() async {
    // 1. Agregar servicios pendientes si los hay
    if (_selectedServices.isNotEmpty) {
      _addServiceAndClear();
    }

    if (_finalServiceList.isEmpty) {
      _showError("Añade al menos un servicio");
      return;
    }

    // 2. Validar datos obligatorios
    final primerGrupo = _finalServiceList.first;
    final tipo = primerGrupo['tipo'] as String?;
    final servicios = primerGrupo['servicios'] as List<String>?;

    if (tipo == null || tipo.isEmpty) {
      _showError("El tipo de servicio no es válido");
      return;
    }
    if (servicios == null || servicios.isEmpty) {
      _showError("No hay servicios seleccionados");
      return;
    }
    if (widget.userId.isEmpty) {
      _showError("ID de usuario no disponible");
      return;
    }

    final lat = _currentLatLng?.latitude;
    final lng = _currentLatLng?.longitude;
    if (lat == null || lng == null) {
      _showError("Ubicación no disponible. Intenta de nuevo.");
      return;
    }

    // 3. Construir JSON
    final body = jsonEncode({
      'userId': widget.userId,
      'tipo': tipo,
      'servicios': servicios,
      'ubicacion': {
        'direccion': _realAddress,
        'coordenadas': {'lat': lat, 'lng': lng},
      },
    });

    // 4. ACTIVAR ESTADO DE CARGA EN LA TARJETA (reemplaza al diálogo)
    setState(() {
      _isLoadingService = true;
      _isExpanded = false; // opcional: colapsar la tarjeta a tamaño pequeño
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/service-requests'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // 5. DESACTIVAR CARGA
      setState(() {
        _isLoadingService = false;
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('DEBUG: Respuesta completa: $data'); // Para depuración

        // Intentar obtener el ID de varias formas
        final serviceId =
            data['serviceRequestId']?.toString() ??
            data['ServiceRequestId']?.toString() ??
            data['_id']?.toString() ??
            data['id']?.toString() ??
            data['data']?['id']?.toString();

        if (serviceId == null || serviceId.isEmpty) {
          _showError("No se pudo obtener el ID del servicio");
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingScreen(serviceRequestId: serviceId),
          ),
        );
      } else {
        _showError(
          "Error al crear la solicitud (código ${response.statusCode})",
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingService = false;
      });
      _showError("Error de conexión: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // -------------------------------------------------------------
  // FIN MÉTODO CONFIRMACIÓN
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentLatLng == null
              ? const Center(child: CircularProgressIndicator())
              : AppleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 15,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),

          // HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const Text(
                        "Selecciona el tipo de servicio",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // BOTONES FLOTANTES
          Positioned(
            right: 20,
            top: 130,
            child: Column(
              children: [
                _iconBtn(
                  Icons.person_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserPerfilScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _iconBtn(
                  Icons.my_location,
                  isCircle: true,
                  onTap: _determinePosition,
                ),
              ],
            ),
          ),

          // TARJETA INFERIOR DINÁMICA
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 15),
                ],
              ),
              // CONTENIDO CONDICIONAL
              child: _isLoadingService
                  ? _buildLoadingBody() // <-- NUEVA VISTA DE CARGA
                  : (_isExpanded ? _buildExpandedBody() : _buildInitialBody()),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // NUEVO: CUERPO DE LA TARJETA EN ESTADO DE CARGA
  // -------------------------------------------------------------
  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.search,
                color: Colors.blue,
              ), // Icono de búsqueda
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Buscando barbero",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    "Espera un momento...",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 16),
        const Text(
          "Conectando con barberos cercanos",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        // Botón opcional para cancelar la búsqueda
        SizedBox(
          width: double.infinity,
          height: 45,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _isLoadingService = false;
                // Podrías también cancelar la petición HTTP si usas http.Client()
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text("Cancelar"),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // CUERPOS ORIGINALES (SIN CAMBIOS)
  // -------------------------------------------------------------
  Widget _buildInitialBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: Colors.blue),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tu Ubicación",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    _realAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _blueBtn(
          "Solicitar Servicio",
          () => setState(() => _isExpanded = true),
        ),
      ],
    );
  }

  Widget _buildExpandedBody() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tipo de servicio:",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.blue,
                  ),
                  onPressed: () => setState(() => _isExpanded = false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _typeCard(
                  "Servicio propio",
                  Icons.person,
                  _selectedType == "propio",
                  () => setState(() => _selectedType = "propio"),
                ),
                const SizedBox(width: 12),
                _typeCard(
                  "Servicio a segundo",
                  Icons.group_add,
                  _selectedType == "segundo",
                  () => setState(() => _selectedType = "segundo"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Servicio a solicitar:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _serviceChip("Corte", Icons.content_cut),
                _serviceChip("Barba", Icons.face),
                _serviceChip("Tinte", Icons.color_lens),
                _serviceChip("Combo", Icons.auto_awesome),
                _serviceChip("Cejas", Icons.remove_red_eye_outlined),
              ],
            ),
            const SizedBox(height: 15),

            // BOTÓN AÑADIR SERVICIO
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addServiceAndClear,
                icon: const Icon(Icons.add),
                label: const Text("Añadir servicio"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            if (_finalServiceList.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "Servicios añadidos:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._finalServiceList.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "${index + 1}.",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${item['servicios'].join(", ")} (${item['tipo']})",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _finalServiceList.removeAt(index)),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),
            const Text(
              "Ubicación:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              _realAddress,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _blueBtn("Confirmar Servicio", _confirmarServicio),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES VISUALES (sin cambios) ---
  Widget _typeCard(
    String text,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.blue[50],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.blue : Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceChip(String text, IconData icon) {
    bool isSelected = _selectedServices.contains(text);
    return GestureDetector(
      onTap: () => setState(() {
        isSelected
            ? _selectedServices.remove(text)
            : _selectedServices.add(text);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 8,
              backgroundColor: Colors.white,
              child: Icon(
                icon,
                size: 10,
                color: isSelected ? Colors.blue : Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserPerfilScreen()),
        ).then((_) => _loadUserPhoto());
      },
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(15),
          image: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
              ? DecorationImage(
                  image: NetworkImage('$baseUrl$profileImageUrl'),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: (profileImageUrl == null || profileImageUrl!.isEmpty)
            ? const Center(
                child: Icon(Icons.person, color: Colors.blue, size: 40),
              )
            : null,
      ),
    );
  }

  Widget _blueBtn(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool isCircle = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Icon(icon, color: Colors.blue, size: 22),
      ),
    );
  }
}
