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
import 'package:barber_app/screens/User_Screens/change_location_screen.dart';

class UserMapScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserMapScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserMapScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserMapScreen> {
  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  String? profileImageUrl;

  final String baseUrl = AppConfig.baseUrl;

  String _realAddress = "Obteniendo ubicación...";
  bool _isExpanded = false;
  bool _isLoadingService = false;

  final String _selectedType = "propio";
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
    });
  }

  Future<void> _confirmarServicio() async {
    if (_selectedServices.isNotEmpty) {
      _addServiceAndClear();
    }

    if (_finalServiceList.isEmpty) {
      _showError("Añade al menos un servicio");
      return;
    }

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

    final body = jsonEncode({
      'userId': widget.userId,
      'tipo': tipo,
      'servicios': servicios,
      'ubicacion': {
        'direccion': _realAddress,
        'coordenadas': {'lat': lat, 'lng': lng},
      },
    });

    setState(() {
      _isLoadingService = true;
      _isExpanded = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/service-requests'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      setState(() {
        _isLoadingService = false;
      });

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

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
      extendBody: true,
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Row(
                children: [
                  // Ícono de flecha para regresar
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  _buildAvatar(),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          "Selecciona el tipo de servicio",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

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

          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isLoadingService
                  ? _buildLoadingBody()
                  : (_isExpanded ? _buildExpandedBody() : _buildInitialBody()),
            ),
          ),
        ],
      ),
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
              child: const Icon(Icons.search, color: Colors.blue),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Buscando barbero",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    "Espera un momento...",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        const CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        const SizedBox(height: 20),
        const Text(
          "Conectando con barberos cercanos",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => setState(() => _isLoadingService = false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Cancelar"),
          ),
        ),
      ],
    );
  }

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
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    _realAddress,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _blueBtn(
          "SOLICITAR SERVICIO",
          () => setState(() => _isExpanded = true),
        ),
      ],
    );
  }

  Widget _buildExpandedBody() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                // Botón para cerrar/contraer el menú
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => setState(() => _isExpanded = false),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Center(
              child: SizedBox(
                width: 140,
                child: _newTypeCard(
                  "Servicio propio",
                  Icons.account_circle,
                  true,
                  () {},
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              "Servicio a solicitar:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(child: _newServiceChip("Corte", Icons.content_cut)),
                const SizedBox(width: 15),
                Expanded(child: _newServiceChip("Barba", Icons.face)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _newServiceChip("Ceja", Icons.remove_red_eye_outlined),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _newServiceChip("Greka", Icons.design_services),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_finalServiceList.isEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: _addServiceAndClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    side: BorderSide(color: Colors.blue[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Añadir servicio",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Añadir servicios:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: _addServiceAndClear,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ..._finalServiceList.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        "${index + 1}. ",
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        item['servicios'].join(", "),
                        style: const TextStyle(fontSize: 13),
                      ),
                      Expanded(
                        child: Text(
                          " . " * 30,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                      const Text(
                        "\$000.00",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _finalServiceList.removeAt(index)),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ubicación:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nuevaDireccion = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeLocationScreen(
                          initialAddress: _realAddress,
                          initialLocation: _currentLatLng,
                        ),
                      ),
                    );

                    if (nuevaDireccion != null && nuevaDireccion is String) {
                      setState(() {
                        _realAddress = nuevaDireccion;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    elevation: 0,
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Cambiar ubicación",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on, color: Colors.blue[600]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _realAddress,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            _blueBtn("CONFIRMAR SERVICIO", _confirmarServicio),
          ],
        ),
      ),
    );
  }

  Widget _newTypeCard(
    String text,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newServiceChip(String text, IconData icon) {
    bool isSelected = _selectedServices.contains(text);
    return GestureDetector(
      onTap: () => setState(() {
        isSelected
            ? _selectedServices.remove(text)
            : _selectedServices.add(text);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.blue[400],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(15),
          image: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
              ? DecorationImage(
                  image: NetworkImage('$baseUrl$profileImageUrl'),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: (profileImageUrl == null || profileImageUrl!.isEmpty)
            ? Center(
                child: Icon(Icons.person, color: Colors.blue[700], size: 30),
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
          backgroundColor: Colors.blue[600],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool isCircle = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Icon(icon, color: Colors.blue[700], size: 22),
      ),
    );
  }
}