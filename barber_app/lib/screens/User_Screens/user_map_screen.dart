import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barber_app/config/app_config.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_reservations_screen.dart';
import 'package:barber_app/screens/Main_Screens/waiting_screen.dart';
import 'package:barber_app/screens/User_Screens/change_location_screen.dart';

// ─────────────────────────────────────────────
//  COLORES
// ─────────────────────────────────────────────
const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

class UserMapScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserMapScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserMapScreen> createState() => _UserMapScreenState();
}

class _UserMapScreenState extends State<UserMapScreen> {
  AppleMapController? _mapController;
  LatLng?  _currentLatLng;
  String?  _profileImageUrl;
  final String baseUrl = AppConfig.baseUrl;

  String _realAddress      = "Obteniendo ubicación...";
  bool   _isExpanded       = false;
  bool   _isLoadingService = false;

  final String       _selectedType     = "propio";
  final Set<String>  _selectedServices = {};
  final List<Map<String, dynamic>> _finalServiceList = [];

  final List<Map<String, dynamic>> _servicios = [
    {'nombre': 'Corte', 'icono': Icons.content_cut},
    {'nombre': 'Barba', 'icono': Icons.face},
    {'nombre': 'Ceja',  'icono': Icons.remove_red_eye},
    {'nombre': 'Greka', 'icono': Icons.design_services},
  ];

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
    setState(() => _profileImageUrl = prefs.getString('profileImage'));
  }

  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(position.latitude, position.longitude);
      List<Placemark> p = await placemarkFromCoordinates(
        position.latitude, position.longitude);
      setState(() {
        _realAddress = "${p[0].street}, ${p[0].locality}, ${p[0].administrativeArea}";
      });
      _centerMapWithZoom();
    } catch (_) {
      setState(() => _realAddress = "Ubicación no disponible");
    }
  }

  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLatLng!, zoom: 18.0)));
    }
  }

  void _addServiceAndClear() {
    if (_selectedServices.isEmpty) {
      _mostrarSnack('Selecciona al menos un servicio');
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
    if (_selectedServices.isNotEmpty) _addServiceAndClear();
    if (_finalServiceList.isEmpty) {
      _mostrarSnack('Añade al menos un servicio');
      return;
    }

    final primerGrupo = _finalServiceList.first;
    final tipo        = primerGrupo['tipo'] as String?;
    final servicios   = primerGrupo['servicios'] as List<String>?;
    final lat         = _currentLatLng?.latitude;
    final lng         = _currentLatLng?.longitude;

    if (tipo == null || tipo.isEmpty || servicios == null || servicios.isEmpty) {
      _mostrarSnack('El tipo de servicio no es válido');
      return;
    }
    if (lat == null || lng == null) {
      _mostrarSnack('Ubicación no disponible. Intenta de nuevo.');
      return;
    }

    setState(() { _isLoadingService = true; _isExpanded = false; });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/service-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId':   widget.userId,
          'tipo':     tipo,
          'servicios': servicios,
          'ubicacion': {
            'direccion':   _realAddress,
            'coordenadas': {'lat': lat, 'lng': lng},
          },
        }),
      );

      setState(() => _isLoadingService = false);

      if (response.statusCode == 201) {
        final data      = jsonDecode(response.body);
        final serviceId = data['ServiceRequestId']?.toString() ?? data['id']?.toString();
        if (serviceId == null) {
          _mostrarSnack('Error al procesar la respuesta del servidor');
          return;
        }
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => WaitingScreen(serviceRequestId: serviceId)));
      } else {
        _mostrarSnack('Error al crear la solicitud');
      }
    } catch (_) {
      setState(() => _isLoadingService = false);
      _mostrarSnack('Error de conexión');
    }
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── MAPA ────────────────────────────────────────────────────
          _currentLatLng == null
              ? Container(
                  color: _kFondo,
                  child: const Center(child: CircularProgressIndicator(color: _kAzulMedio)))
              : AppleMap(
                  initialCameraPosition: CameraPosition(target: _currentLatLng!, zoom: 15),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),

          // ── HEADER ────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Row(
                    children: [
                      // Botón back
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _kBlanco.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: _kNavy, size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Avatar real del usuario
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const UserPerfilScreen()))
                            .then((_) => _loadUserPhoto()),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kBlanco.withOpacity(0.8), width: 2),
                            color: _kBlanco.withOpacity(0.2),
                            image: _profileImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage('$baseUrl$_profileImageUrl'),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: _profileImageUrl == null
                              ? Icon(Icons.person_rounded, color: _kBlanco.withOpacity(0.9), size: 24)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.userName,
                              style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold, color: _kBlanco)),
                            Text('Servicio a domicilio',
                              style: TextStyle(
                                color: _kBlanco.withOpacity(0.75), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BOTÓN MI UBICACIÓN ────────────────────────────────────
          Positioned(
            right: 16, bottom: 300,
            child: GestureDetector(
              onTap: _centerMapWithZoom,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kBlanco,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
                ),
                child: const Icon(Icons.my_location_rounded, color: _kAzulMedio, size: 22),
              ),
            ),
          ),

          // ── PANEL INFERIOR ────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              decoration: BoxDecoration(
                color: _kBlanco,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -4))
                ],
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: _isLoadingService
                      ? _buildLoadingBody()
                      : _isExpanded
                          ? _buildExpandedBody()
                          : _buildInitialBody(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildLiquidBar(),
    );
  }

  // ── PANEL INICIAL ─────────────────────────────────────────────────
  Widget _buildInitialBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.location_on_rounded, color: _kAzulMedio, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tu ubicación',
                    style: TextStyle(color: Color(0xFF8892B0), fontSize: 11, fontWeight: FontWeight.w500)),
                  Text(_realAddress,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kNavy),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _isExpanded = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: const Text('SOLICITAR SERVICIO',
              style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // ── PANEL EXPANDIDO ───────────────────────────────────────────────
  Widget _buildExpandedBody() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle + título
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(width: 4, height: 18,
                  decoration: BoxDecoration(color: _kAzulMedio, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('Selecciona servicios',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
              ]),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = false),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close, size: 16, color: _kNavy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid de servicios
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _servicios.map((s) {
              final sel = _selectedServices.contains(s['nombre']);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedServices.remove(s['nombre']);
                  } else {
                    _selectedServices.add(s['nombre'] as String);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? _kNavy : _kBlanco,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? _kNavy : const Color(0xFFE0E8FF), width: 0.5)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s['icono'] as IconData, size: 15,
                        color: sel ? _kBlanco : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(s['nombre'] as String,
                        style: TextStyle(
                          color: sel ? _kBlanco : _kNavy,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Botón añadir a lista
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addServiceAndClear,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('AÑADIR A LA LISTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kAzulMedio,
                side: const BorderSide(color: Color(0xFFD0DCFF), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Lista de servicios añadidos
          if (_finalServiceList.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: [
              Container(width: 4, height: 14,
                decoration: BoxDecoration(color: Colors.green.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Servicios añadidos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 8),
            ..._finalServiceList.asMap().entries.map((entry) {
  final idx = entry.key;
  final svs = List<String>.from(entry.value['servicios']);
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4FF),
      borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: _kNavy,
            borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text('${idx + 1}',
              style: const TextStyle(
                color: _kBlanco, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(svs.join(', '),
          style: const TextStyle(fontSize: 12, color: _kNavy, fontWeight: FontWeight.w500))),
        GestureDetector(
          onTap: () => setState(() => _finalServiceList.removeAt(idx)),
          child: const Icon(Icons.close, size: 16, color: Colors.red)),
      ],
    ),
  );
}),
          ],

          const SizedBox(height: 14),

          // Ubicación
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: _kAzulMedio, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_realAddress,
                    style: const TextStyle(fontSize: 12, color: _kNavy, fontWeight: FontWeight.w500),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChangeLocationScreen(
                        initialAddress: _realAddress,
                        initialLocation: _currentLatLng,
                      )));
                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        _realAddress   = result['direccion'];
                        _currentLatLng = LatLng(result['lat'], result['lng']);
                      });
                      _centerMapWithZoom();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Text('Cambiar',
                      style: TextStyle(fontSize: 11, color: _kBlanco, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Botón confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmarServicio,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text('CONFIRMAR SERVICIO',
                style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── PANEL CARGANDO ────────────────────────────────────────────────
  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(18)),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(color: _kAzulMedio, strokeWidth: 3)),
        ),
        const SizedBox(height: 16),
        const Text('Buscando barbero...',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy)),
        const SizedBox(height: 4),
        Text('Espera un momento',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _isLoadingService = false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Color(0xFFFFCDD2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── LIQUID BAR ────────────────────────────────────────────────────
  Widget _buildLiquidBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: _kBlanco.withOpacity(0.25),
              border: Border.all(color: _kBlanco.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(Icons.home_filled,    'Inicio',    true,  () => Navigator.pop(context)),
                _buildTabItem(Icons.description,    'Servicios', false, () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserServicesScreen()))),
                _buildTabItem(Icons.calendar_month, 'Reservas',  false, () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserReservationsScreen(userId: widget.userId)))),
                _buildTabItem(Icons.person,         'Perfil',    false, () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPerfilScreen()))
                    .then((_) => _loadUserPhoto())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22,
            color: selected ? Colors.grey.shade500 : _kAzulMedio),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.grey.shade500 : _kAzulMedio)),
        ],
      ),
    );
  }
}