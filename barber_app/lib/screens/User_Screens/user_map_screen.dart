import 'dart:async';
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
import 'package:barber_app/screens/User_Screens/change_location_screen.dart';

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);
const _kDorado    = Color(0xFFF59E0B);

class UserMapScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const UserMapScreen({super.key, required this.userId, required this.userName});

  @override
  State<UserMapScreen> createState() => _UserMapScreenState();
}

class _UserMapScreenState extends State<UserMapScreen> {
  AppleMapController? _mapController;
  LatLng?  _currentLatLng;
  String?  _profileImageUrl;
  final String baseUrl = AppConfig.baseUrl;

Map<String, dynamic>? _desglosePrecio;

  String _realAddress       = "Obteniendo ubicación...";
  bool   _isExpanded        = false;
  bool   _isLoadingService  = false;

  // ── Estado solicitud ──────────────────────────────────────────
  String? _solicitudId;
  Timer?  _pollingTimer;
  bool    _barberoAsignado  = false;
  bool    _servicioIniciado = false;
  bool    _servicioFinalizado = false;
  int     _costoTotal       = 0;

  // ── Datos del barbero asignado ────────────────────────────────
  String? _barberoNombre;
  String? _barberoFoto;
  double  _barberoPromedio  = 0;
  int     _barberoResenias  = 0;
  LatLng? _barberoLatLng;
  final Set<Annotation> _mapAnnotations = {};

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

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
        desiredAccuracy: LocationAccuracy.high);
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
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLatLng!, zoom: 18.0)));
    }
  }

  // ── Polling ───────────────────────────────────────────────────
  void _startPolling(String solicitudId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _checkEstado(solicitudId);
    });
  }
  Widget _buildDesgloseFila(String label, String valor, Color color) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: color, fontSize: 12)),
      Text(valor, style: TextStyle(
        color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );
}

  Future<void> _checkEstado(String solicitudId) async {
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/service-requests/$solicitudId/estado'));
    if (res.statusCode != 200) return;

    final data   = jsonDecode(res.body);
    final estado = data['estado']?.toString() ?? '';

    if ((estado == 'barbero_asignado' || estado == 'en_camino') && !_servicioIniciado) {
      final info = data['barberoInfo'];
      final loc  = info?['lastLocation'];
      setState(() {
        _barberoAsignado  = true;
        _isLoadingService = false;
        _barberoNombre    = info?['nombre'] ?? 'Barbero';
        _barberoFoto      = info?['profileImage'];
        _barberoPromedio  = (info?['calificacion']?['promedio'] ?? 0).toDouble();
        _barberoResenias  = ((info?['calificacion']?['totalReseñas'] ?? 0) as num).toInt();
        if (loc?['lat'] != null && loc?['lng'] != null) {
          _barberoLatLng = LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
          _updateBarberMarker();
        }
      });
    }

    if (estado == 'en_servicio' && !_servicioIniciado) {
      final info = data['barberoInfo'];
      setState(() {
        _servicioIniciado = true;
        _barberoAsignado  = true;
        _isLoadingService = false;
        _barberoNombre    = info?['nombre'] ?? 'Barbero';
        _barberoFoto      = info?['profileImage'];
        _barberoPromedio  = (info?['calificacion']?['promedio'] ?? 0).toDouble();
        _barberoResenias  = ((info?['calificacion']?['totalReseñas'] ?? 0) as num).toInt();
      });
      _mostrarSnackLlegada();
    }

    if (estado == 'finalizado' && !_servicioFinalizado) {
      setState(() => _servicioFinalizado = true);
      _pollingTimer?.cancel();
      final costo = ((data['costoTotal'] ?? 0) as num).toInt();
      setState(() {
        _costoTotal     = costo;
        _desglosePrecio = data['desglosePrecio']; // ← nuevo
      });
      _mostrarResumenFinal();
    }

    if (estado == 'cancelado') {
      _pollingTimer?.cancel();
      setState(() {
        _barberoAsignado  = false;
        _isLoadingService = false;
        _solicitudId      = null;
      });
      _mostrarSnack('La solicitud fue cancelada');
    }

  } catch (_) {}
}
 void _mostrarSnackLlegada() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row( 
        children: [
          const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded( 
            child: const Text(
              '¡Tu barbero ha llegado! El servicio está en curso',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _updateBarberMarker() {
    if (_barberoLatLng == null) return;
    setState(() {
      _mapAnnotations.removeWhere((a) => a.annotationId.value == 'barbero');
      _mapAnnotations.add(Annotation(
        annotationId: AnnotationId('barbero'),
        position: _barberoLatLng!,
        infoWindow: InfoWindow(title: _barberoNombre ?? 'Barbero'),
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueCyan),
      ));
    });
    if (_currentLatLng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            [_currentLatLng!.latitude, _barberoLatLng!.latitude].reduce((a, b) => a < b ? a : b) - 0.005,
            [_currentLatLng!.longitude, _barberoLatLng!.longitude].reduce((a, b) => a < b ? a : b) - 0.005,
          ),
          northeast: LatLng(
            [_currentLatLng!.latitude, _barberoLatLng!.latitude].reduce((a, b) => a > b ? a : b) + 0.005,
            [_currentLatLng!.longitude, _barberoLatLng!.longitude].reduce((a, b) => a > b ? a : b) + 0.005,
          ),
        ),
        80,
      ));
    }
  }

  // ── Resumen final ─────────────────────────────────────────────
  void _mostrarResumenFinal() {
  if (!mounted) return;
  final servicios = _finalServiceList.isNotEmpty
      ? List<String>.from(_finalServiceList.first['servicios'])
      : <String>[];

  showModalBottomSheet(
    context: context,
    isDismissible: false,
     isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),

        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.green.withOpacity(0.25), width: 1.5)),
          child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 42)),
        const SizedBox(height: 14),

        const Text('¡Servicio completado!',
          style: TextStyle(color: _kBlanco, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${_barberoNombre ?? 'Tu barbero'} ha terminado',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Column(children: [
              // ── Barbero ──────────────────────────────────────
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white10,
                    image: _barberoFoto != null
                        ? DecorationImage(
                            image: NetworkImage('$baseUrl$_barberoFoto'),
                            fit: BoxFit.cover)
                        : null),
                  child: _barberoFoto == null
                      ? const Icon(Icons.person_rounded, color: Colors.white54, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_barberoNombre ?? 'Barbero',
                      style: const TextStyle(color: _kBlanco, fontSize: 14, fontWeight: FontWeight.w600)),
                    Row(children: [
                      ...List.generate(5, (i) => Icon(
                        i < _barberoPromedio.floor()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: _kDorado, size: 11)),
                      const SizedBox(width: 4),
                      Text(_barberoPromedio.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ]),
                  ],
                )),
              ]),

              const Divider(color: Colors.white12, height: 20),

              // ── Servicios ─────────────────────────────────────
              if (servicios.isNotEmpty) ...[
                Row(children: [
                  const Icon(Icons.content_cut_rounded, color: Colors.white38, size: 13),
                  const SizedBox(width: 6),
                  Text(servicios.join(' · '),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
                const SizedBox(height: 14),
              ],

              // ── Desglose ──────────────────────────────────────
              if (_desglosePrecio != null) ...[
                _buildDesgloseFila(
                  'Servicios',
                  '\$${_desglosePrecio!['precioBase']}',
                  Colors.white70),
                const SizedBox(height: 8),
                _buildDesgloseFila(
                  'Traslado',
                  '\$${_desglosePrecio!['traslado']}',
                  Colors.white70),
                const SizedBox(height: 8),
                _buildDesgloseFila(
                  'Comisión plataforma',
                  '\$${_desglosePrecio!['comision']}',
                  Colors.white54),
                const SizedBox(height: 8),
                _buildDesgloseFila(
                  'IVA (16%)',
                  '\$${((_desglosePrecio!['total'] as num).toInt() - (_desglosePrecio!['subtotal'] as num).toInt())}',
                  Colors.white54),
                const Divider(color: Colors.white12, height: 20),
              ],

              // ── Total ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kDorado.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kDorado.withOpacity(0.25))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('\$$_costoTotal',
                      style: const TextStyle(
                        color: _kDorado, fontWeight: FontWeight.bold, fontSize: 24)),
                  ],
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _barberoAsignado    = false;
                  _servicioIniciado   = false;
                  _servicioFinalizado = false;
                  _solicitudId        = null;
                  _barberoLatLng      = null;
                  _mapAnnotations.clear();
                  _finalServiceList.clear();
                  _costoTotal         = 0;
                  _desglosePrecio     = null; // ← limpiar
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAzulMedio,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0),
              child: const Text('CERRAR',
                style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
      ]),
    ),
  );
}

  // ── Servicio ──────────────────────────────────────────────────
  void _addServiceAndClear() {
    if (_selectedServices.isEmpty) {
      _mostrarSnack('Selecciona al menos un servicio');
      return;
    }
    setState(() {
      _finalServiceList.add({
        'tipo':      _selectedType,
        'servicios': _selectedServices.toList(),
      });
      _selectedServices.clear();
    });
  }

  Future<void> _confirmarServicio() async {
    if (_selectedServices.isNotEmpty) _addServiceAndClear();
    if (_finalServiceList.isEmpty) { _mostrarSnack('Añade al menos un servicio'); return; }

    final primerGrupo = _finalServiceList.first;
    final tipo        = primerGrupo['tipo'] as String?;
    final servicios   = primerGrupo['servicios'] as List<String>?;
    final lat = _currentLatLng?.latitude;
    final lng = _currentLatLng?.longitude;

    if (tipo == null || servicios == null || servicios.isEmpty) { _mostrarSnack('Servicio inválido'); return; }
    if (lat == null || lng == null) { _mostrarSnack('Ubicación no disponible'); return; }

    setState(() { _isLoadingService = true; _isExpanded = false; });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/service-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId':    widget.userId,
          'tipo':      tipo,
          'servicios': servicios,
          'ubicacion': {
            'direccion':   _realAddress,
            'coordenadas': {'lat': lat, 'lng': lng},
          },
        }),
      );

      if (response.statusCode == 201) {
        final data      = jsonDecode(response.body);
        final serviceId = data['ServiceRequestId']?.toString();
        if (serviceId == null) {
          setState(() => _isLoadingService = false);
          _mostrarSnack('Error al procesar la respuesta');
          return;
        }
        setState(() => _solicitudId = serviceId);
        _startPolling(serviceId);

        // Timeout 2 min
        Future.delayed(const Duration(minutes: 2), () {
          if (mounted && _isLoadingService && !_barberoAsignado) {
            _pollingTimer?.cancel();
            setState(() => _isLoadingService = false);
            _mostrarSnack('No se encontró barbero disponible. Intenta de nuevo.');
          }
        });
      } else {
        setState(() => _isLoadingService = false);
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

  // ── Build ─────────────────────────────────────────────────────
  @override
Widget build(BuildContext context) {
  return Scaffold(
    extendBody: true,
    body: Stack(
      children: [
        // ... todo igual, no tocar
        _currentLatLng == null
            ? Container(color: _kFondo,
                child: const Center(child: CircularProgressIndicator(color: _kAzulMedio)))
            : AppleMap(
                initialCameraPosition: CameraPosition(target: _currentLatLng!, zoom: 15),
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                annotations: _mapAnnotations,
              ),

        // Header — igual
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.35), Colors.transparent])),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // ← único modo de salir
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _kBlanco.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new, color: _kNavy, size: 16)),
                  ),
                  const SizedBox(width: 12),
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
                            : null),
                      child: _profileImageUrl == null
                          ? Icon(Icons.person_rounded, color: _kBlanco.withOpacity(0.9), size: 24)
                          : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.userName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kBlanco)),
                      Text('Servicio a domicilio',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        ),

        // Botón centrar — igual
        Positioned(
          right: 16, bottom: 310,
          child: GestureDetector(
            onTap: _centerMapWithZoom,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _kBlanco, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)]),
              child: const Icon(Icons.my_location_rounded, color: _kAzulMedio, size: 22)),
          ),
        ),

        // Panel inferior — igual, pero sin el margin de 120 abajo, ahora 40
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 40), // ← era 120, ahora 40
            decoration: BoxDecoration(
              color: _kBlanco, borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -4))]),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: _barberoAsignado
                    ? _buildBarberAssignedBody()
                    : _isLoadingService
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
   
  );
}

  // ── Card barbero asignado ─────────────────────────────────────
 Widget _buildBarberAssignedBody() {
  final badgeColor = _servicioIniciado ? Colors.orange : Colors.green;
  final badgeTexto = _servicioIniciado ? 'Servicio en curso' : 'Barbero en camino';
  final badgeIcono = _servicioIniciado ? Icons.content_cut_rounded : Icons.directions_car_rounded;
  final serviciosTexto = _finalServiceList.isNotEmpty
      ? List<String>.from(_finalServiceList.first['servicios']).join(' · ')
      : 'Servicio solicitado';

  return Column(mainAxisSize: MainAxisSize.min, children: [
    Center(child: Container(width: 36, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
    const SizedBox(height: 16),

    // ── Fila barbero + badge ──────────────────────────────────
    Row(children: [
      // Foto
      Stack(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFEEF4FF),
            border: Border.all(color: const Color(0xFFD0DCFF), width: 1.5),
            image: _barberoFoto != null
                ? DecorationImage(
                    image: NetworkImage('$baseUrl$_barberoFoto'),
                    fit: BoxFit.cover)
                : null),
          child: _barberoFoto == null
              ? const Icon(Icons.person_rounded, color: _kAzulMedio, size: 30)
              : null,
        ),
        // Dot estado
        Positioned(
          bottom: 0, right: 0,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
      ]),
      const SizedBox(width: 14),

      // Info
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_barberoNombre ?? 'Barbero',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
          const SizedBox(height: 3),
          Row(children: [
            ...List.generate(5, (i) => Icon(
              i < _barberoPromedio.floor()
                  ? Icons.star_rounded
                  : i < _barberoPromedio
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              color: _kDorado, size: 13)),
            const SizedBox(width: 4),
            Text('${_barberoPromedio.toStringAsFixed(1)} · $_barberoResenias reseñas',
              style: const TextStyle(fontSize: 10, color: Color(0xFF8892B0))),
          ]),
          const SizedBox(height: 4),
          // Badge estado inline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Icon(badgeIcono, color: badgeColor, size: 11),
              const SizedBox(width: 4),
              Text(badgeTexto,
                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      )),

      // Spinner
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: CircularProgressIndicator(color: badgeColor, strokeWidth: 2.5)),
      ),
    ]),

    const SizedBox(height: 16),

    // ── Servicios ─────────────────────────────────────────────
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _kNavy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.content_cut_rounded, color: _kNavy, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Servicios solicitados',
              style: TextStyle(fontSize: 10, color: Color(0xFF8892B0), fontWeight: FontWeight.w500)),
            Text(serviciosTexto,
              style: const TextStyle(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w600)),
          ],
        )),
      ]),
    ),
    const SizedBox(height: 14),

    // ── Botón / estado ────────────────────────────────────────
    if (!_servicioIniciado)
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            if (_barberoLatLng != null && _currentLatLng != null) {
              _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
                LatLngBounds(
                  southwest: LatLng(
                    [_currentLatLng!.latitude, _barberoLatLng!.latitude].reduce((a, b) => a < b ? a : b) - 0.005,
                    [_currentLatLng!.longitude, _barberoLatLng!.longitude].reduce((a, b) => a < b ? a : b) - 0.005,
                  ),
                  northeast: LatLng(
                    [_currentLatLng!.latitude, _barberoLatLng!.latitude].reduce((a, b) => a > b ? a : b) + 0.005,
                    [_currentLatLng!.longitude, _barberoLatLng!.longitude].reduce((a, b) => a > b ? a : b) + 0.005,
                  ),
                ),
                80,
              ));
            }
          },
          icon: const Icon(Icons.navigation_rounded, size: 16),
          label: const Text('VER EN MAPA',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            foregroundColor: _kBlanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0),
        ),
      ),

    if (_servicioIniciado)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.25))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.content_cut_rounded, color: Colors.orange, size: 18)),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu barbero está trabajando',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Espera a que finalice',
                style: TextStyle(color: Colors.orange, fontSize: 11)),
            ],
          ),
        ]),
      ),
  ]);
}
  Widget _buildInitialBody() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(width: 36, height: 4,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.location_on_rounded, color: _kAzulMedio, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu ubicación',
              style: TextStyle(color: Color(0xFF8892B0), fontSize: 11, fontWeight: FontWeight.w500)),
            Text(_realAddress,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kNavy),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => setState(() => _isExpanded = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
          child: const Text('SOLICITAR SERVICIO',
            style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    ]);
  }

  Widget _buildExpandedBody() {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
              child: const Icon(Icons.close, size: 16, color: _kNavy))),
        ]),
        const SizedBox(height: 16),
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
                  border: Border.all(color: sel ? _kNavy : const Color(0xFFE0E8FF), width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(s['icono'] as IconData, size: 15,
                    color: sel ? _kBlanco : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(s['nombre'] as String,
                    style: TextStyle(
                      color: sel ? _kBlanco : _kNavy,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
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
              padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
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
                color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text('${idx + 1}',
                    style: const TextStyle(color: _kBlanco, fontSize: 11, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 10),
                Expanded(child: Text(svs.join(', '),
                  style: const TextStyle(fontSize: 12, color: _kNavy, fontWeight: FontWeight.w500))),
                GestureDetector(
                  onTap: () => setState(() => _finalServiceList.removeAt(idx)),
                  child: const Icon(Icons.close, size: 16, color: Colors.red)),
              ]),
            );
          }),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.location_on_rounded, color: _kAzulMedio, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(_realAddress,
              style: const TextStyle(fontSize: 12, color: _kNavy, fontWeight: FontWeight.w500),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChangeLocationScreen(
                    initialAddress:  _realAddress,
                    initialLocation: _currentLatLng)));
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
                decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(8)),
                child: const Text('Cambiar',
                  style: TextStyle(fontSize: 11, color: _kBlanco, fontWeight: FontWeight.w600))),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmarServicio,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
            child: const Text('CONFIRMAR SERVICIO',
              style: TextStyle(color: _kBlanco, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  Widget _buildLoadingBody() {
  return Column(mainAxisSize: MainAxisSize.min, children: [
    Center(child: Container(width: 36, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
    const SizedBox(height: 24),

    // Animación central
    Stack(alignment: Alignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(22)),
      ),
      const SizedBox(
        width: 72, height: 72,
        child: CircularProgressIndicator(color: _kAzulMedio, strokeWidth: 2.5)),
      const Icon(Icons.content_cut_rounded, color: _kAzulMedio, size: 28),
    ]),
    const SizedBox(height: 18),

    const Text('Buscando tu barbero',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kNavy)),
    const SizedBox(height: 6),
    Text('Estamos conectándote con el más cercano',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      textAlign: TextAlign.center),
    const SizedBox(height: 20),

    // Info ubicación
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kAzulMedio.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.location_on_rounded, color: _kAzulMedio, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu ubicación',
              style: TextStyle(fontSize: 10, color: Color(0xFF8892B0), fontWeight: FontWeight.w500)),
            Text(_realAddress,
              style: const TextStyle(fontSize: 12, color: _kNavy, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    ),
    const SizedBox(height: 16),

    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _pollingTimer?.cancel();
          setState(() { _isLoadingService = false; _solicitudId = null; });
        },
        icon: const Icon(Icons.close_rounded, size: 16),
        label: const Text('Cancelar búsqueda', style: TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade400,
          side: BorderSide(color: Colors.red.shade100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    ),
  ]);
}

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
              border: Border.all(color: _kBlanco.withOpacity(0.4), width: 1.5)),
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
          Icon(icon, size: 22, color: selected ? Colors.grey.shade500 : _kAzulMedio),
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