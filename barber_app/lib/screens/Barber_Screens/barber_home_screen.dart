import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
import 'barber_state.dart';
import 'barber_servicios_screen.dart';
import 'barber_citas_screen.dart';
import 'barber_store_screen.dart';
import 'Barber_Profile_screen.dart';
import 'liquid_glass_bar.dart';

class BarberHomeScreen extends StatefulWidget {
  final String barberId;
  final String barberName;

  const BarberHomeScreen({
    super.key,
    required this.barberId,
    required this.barberName,
  });

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  int _selectedIndex = 0;

  late BarberState _barberState;
  Timer? _runnerTimer;
  String? _ultimaSolicitudId; // para no mostrar la misma dos veces
  bool _mostrandoSheet = false;

  AppleMapController? _mapController;
  LatLng? _currentLatLng;
  String _realAddress = "Obteniendo ubicación...";
  String? _profileImageUrl;
  final String baseUrl = AppConfig.baseUrl;

  String? _solicitudActivaId;
  LatLng? _clienteLatLng;
  List<String> _serviciosActivos = [];
  Timer? _geofenceTimer;
  bool _llegadaMostrada = false;

  @override
  void initState() {
    super.initState();
    _barberState = BarberState(barberId: widget.barberId);
    _barberState.cargarEstado();
    _determinePosition();
    _fetchProfileImage();
    _iniciarPollingRunner();
  }

  @override
  void dispose() {
    _runnerTimer?.cancel();
    _barberState.dispose();
    super.dispose();
  }

  // ── POLLING RUNNER ────────────────────────────────────────────────
  void _iniciarPollingRunner() {
    debugPrint('🚀 Iniciando polling runner...');
    _runnerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _verificarSolicitudesRunner();
    });
  }

  Future<void> _verificarSolicitudesRunner() async {
    if (_mostrandoSheet) return;
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/api/service-requests/barbero/${widget.barberId}/pendientes',
        ),
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final solicitud = data.first;
          final id = solicitud['_id']?.toString() ?? '';
          if (id != _ultimaSolicitudId) {
            _ultimaSolicitudId = id;
            _onNuevaSolicitudRunner(solicitud);
          }
        }
      }
    } catch (_) {}
  }

  void _onNuevaSolicitudRunner(dynamic data) {
    if (!mounted || _mostrandoSheet) return;
    _mostrandoSheet = true;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSolicitudRunnerSheet(data),
    ).then((_) => _mostrandoSheet = false);
  }

 Widget _buildSolicitudRunnerSheet(dynamic data) {
  final servicios = List<String>.from(data['servicios'] ?? []);
  final direccion = data['ubicacion']?['direccion'] ?? 'Sin dirección';
  final solicitudId = data['_id']?.toString() ?? '';
  final userId = data['userId'] is Map ? data['userId']['_id']?.toString() ?? '' : data['userId']?.toString() ?? '';

  // Datos del usuario (ya populados)
  final usuarioNombre = data['userId'] is Map
      ? data['userId']['nombre'] ?? 'Usuario'
      : 'Usuario';
  final usuarioFoto = data['userId'] is Map
      ? data['userId']['profileImage']
      : null;

  // Distancia
  String distanciaStr = '?';
  if (_currentLatLng != null && data['ubicacion']?['coordenadas'] != null) {
    final lat = data['ubicacion']['coordenadas']['lat'];
    final lng = data['ubicacion']['coordenadas']['lng'];
    if (lat != null && lng != null) {
      final d = _calcularDistanciaKm(
        _currentLatLng!.latitude,
        _currentLatLng!.longitude,
        lat.toDouble(),
        lng.toDouble(),
      );
      distanciaStr = d.toStringAsFixed(1);
    }
  }

  return Container(
    decoration: const BoxDecoration(
      color: Color(0xFF12121F),
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header rojo con ícono
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8202A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_run,
                  color: Color(0xFFE8202A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva solicitud',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Servicio Runner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card del cliente
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                // Foto o avatar
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A3E),
                    border: Border.all(
                      color: const Color(0xFFE8202A).withOpacity(0.4),
                      width: 2,
                    ),
                    image: usuarioFoto != null
                        ? DecorationImage(
                            image: NetworkImage('${AppConfig.baseUrl}$usuarioFoto'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: usuarioFoto == null
                      ? const Icon(Icons.person, color: Colors.white54, size: 26)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuarioNombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFE8202A), size: 13),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              direccion,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Badge distancia
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8202A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE8202A).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        distanciaStr,
                        style: const TextStyle(
                          color: Color(0xFFE8202A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'km',
                        style: TextStyle(
                          color: Color(0xFFE8202A),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Servicios chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.content_cut, color: Colors.white38, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'SERVICIOS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: servicios.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Botones
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Rechazar',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _aceptarSolicitudRunner(
                      solicitudId,
                      userId,
                      servicios,
                      data['ubicacion']?['coordenadas'],
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8202A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Aceptar servicio',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  Future<void> _aceptarSolicitudRunner(
  String solicitudId,
  String userId,
  List<String> servicios,
  Map<String, dynamic>? coordenadas,
) async {
  try {
    // Calcular distancia real al aceptar
    double distanciaKm = 1.0;
    if (_currentLatLng != null && coordenadas != null) {
      distanciaKm = _calcularDistanciaKm(
        _currentLatLng!.latitude,
        _currentLatLng!.longitude,
        (coordenadas['lat'] as num).toDouble(),
        (coordenadas['lng'] as num).toDouble(),
      );
    }

    await http.put(
      Uri.parse('$baseUrl/api/service-requests/$solicitudId/aceptar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'barberId':    widget.barberId,
        'barberName':  widget.barberName,
        'distanciaKm': distanciaKm, // ← agrega esto
      }),
    );

    setState(() {
      _solicitudActivaId = solicitudId;
      _serviciosActivos  = servicios;
      _llegadaMostrada   = false;
      if (coordenadas != null) {
        _clienteLatLng = LatLng(
          (coordenadas['lat'] as num).toDouble(),
          (coordenadas['lng'] as num).toDouble(),
        );
      }
    });
    _iniciarGeofence();
  } catch (e) {
    debugPrint('Error aceptar runner: $e');
  }
}
  // ── Geofence ─────────────────────────────────────────────────────
  void _iniciarGeofence() {
    _geofenceTimer?.cancel();
    _geofenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _verificarLlegada();
    });
  }

  Future<void> _verificarLlegada() async {
    if (_llegadaMostrada || _clienteLatLng == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final distancia = _calcularDistanciaKm(
        pos.latitude,
        pos.longitude,
        _clienteLatLng!.latitude,
        _clienteLatLng!.longitude,
      );
      debugPrint(
        '📍 Distancia al cliente: ${(distancia * 1000).toStringAsFixed(0)}m',
      );
      if (distancia * 1000 <= 100) {
        // 100 metros
        _geofenceTimer?.cancel();
        _llegadaMostrada = true;
        _mostrarSheetLlegada();
      }
    } catch (e) {
      debugPrint('Error geofence: $e');
    }
  }

  void _mostrarSheetLlegada() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildLlegadaSheet(),
    );
  }

  Widget _buildLlegadaSheet() {
    const kRojo = Color(0xFFE8202A);
    const kNavy = Color(0xFF1A1A2E);
    const kBlanco = Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Ícono llegada
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.green,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            '¡Llegaste al destino!',
            style: TextStyle(
              color: kBlanco,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _serviciosActivos.join(' · '),
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Botón iniciar servicio
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _iniciarServicio();
              },
              icon: const Icon(Icons.content_cut_rounded, size: 18),
              label: const Text(
                'INICIAR SERVICIO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kRojo,
                foregroundColor: kBlanco,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarServicio() async {
    if (_solicitudActivaId == null) return;
    try {
      await http.put(
        Uri.parse('$baseUrl/api/service-requests/$_solicitudActivaId/llegar'),
        headers: {'Content-Type': 'application/json'},
      );
      _mostrarSheetEnServicio();
    } catch (e) {
      debugPrint('Error iniciar servicio: $e');
    }
  }

 Widget _buildEnServicioSheet() {
  const kRojo   = Color(0xFFE8202A);
  const kNavy   = Color(0xFF1A1A2E);
  const kBlanco = Colors.white;

  return Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      color: kNavy,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kRojo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.content_cut_rounded, color: kRojo, size: 22)),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Servicio en curso',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('Trabajando...',
                style: TextStyle(color: kBlanco, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ]),
        const SizedBox(height: 20),

        // Lista servicios
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.content_cut, color: Colors.white38, size: 13),
                SizedBox(width: 6),
                Text('SERVICIOS',
                  style: TextStyle(
                    color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 1)),
              ]),
              const SizedBox(height: 12),
              ..._serviciosActivos.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: kRojo, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text(s, style: const TextStyle(color: kBlanco, fontSize: 14)),
                ]),
              )),
              const Divider(color: Colors.white12, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                  Row(children: [
                    const Icon(Icons.info_outline, color: Colors.white38, size: 13),
                    const SizedBox(width: 4),
                    Text('Se calcula al finalizar',
                      style: TextStyle(
                        color: Colors.white38, fontSize: 12,
                        fontStyle: FontStyle.italic)),
                  ]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Botón finalizar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _finalizarServicio(0); // ← 0 porque el backend calcula el precio
            },
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('FINALIZAR SERVICIO',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kRojo,
              foregroundColor: kBlanco,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0),
          ),
        ),
      ],
    ),
  );
}

  void _mostrarSheetEnServicio() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildEnServicioSheet(),
    );
  }

  Future<void> _finalizarServicio(int total) async {
  if (_solicitudActivaId == null) return;
  try {
    final res = await http.put(
      Uri.parse('$baseUrl/api/service-requests/$_solicitudActivaId/finalizar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}),
    );

    if (res.statusCode == 200) {
      final data   = jsonDecode(res.body);
      final precio = (data['precio']?['total'] ?? 0) as int;

      setState(() {
        _solicitudActivaId = null;
        _clienteLatLng     = null;
        _serviciosActivos  = [];
        _llegadaMostrada   = false;
      });

      // Mostrar resumen con precio real
      _mostrarResumenFinal(precio);
    }
  } catch (e) {
    debugPrint('Error finalizar: $e');
  }
}

void _mostrarResumenFinal(int precio) {
  if (!mounted) return;
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40)),
          const SizedBox(height: 12),

          const Text('¡Servicio completado!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('El cliente ha sido notificado',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 20),

          // Desglose
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total cobrado',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                  Text('\$$precio',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5FD4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0),
              child: const Text('CERRAR',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );
}

  double _calcularDistanciaKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * 3.14159265358979 / 180;
    final dLng = (lng2 - lng1) * 3.14159265358979 / 180;
    final a =
        (dLat / 2) * (dLat / 2) +
        (lat1 * 3.14159265358979 / 180) *
            (lat2 * 3.14159265358979 / 180) *
            (dLng / 2) *
            (dLng / 2);
    return R * 2 * (a < 1 ? a : 1);
  }

  // ── UBICACIÓN ─────────────────────────────────────────────────────
  Future<void> _actualizarUbicacionBackend(double lat, double lng) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/api/disponibilidad/${widget.barberId}/ubicacion'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'lat': lat, 'lng': lng}),
      );
      debugPrint('Ubicación actualizada en backend: $lat, $lng');
    } catch (e) {
      debugPrint('Error actualizando ubicación: $e');
    }
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _realAddress = "Permiso denegado";
            _currentLatLng = const LatLng(20.7219, -103.3911);
          });
          _centerMapWithZoom();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _realAddress = "Activa la ubicación en Ajustes";
          _currentLatLng = const LatLng(20.7219, -103.3911);
        });
        _centerMapWithZoom();
        return;
      }

      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        setState(() {
          _currentLatLng = LatLng(
            lastPosition.latitude,
            lastPosition.longitude,
          );
          _realAddress = "Cargando dirección...";
        });
        _centerMapWithZoom();
      }

      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('timeout'),
          );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _realAddress = "${placemarks[0].street}, ${placemarks[0].locality}";
      });
      _centerMapWithZoom();
      _actualizarUbicacionBackend(position.latitude, position.longitude);
    } catch (e) {
      if (_currentLatLng == null) {
        _currentLatLng = const LatLng(20.7219, -103.3911);
        _centerMapWithZoom();
      }
      setState(() {
        if (_realAddress == "Obteniendo ubicación..." ||
            _realAddress == "Cargando dirección...") {
          _realAddress = "Ubicación aproximada";
        }
      });
    }
  }

  void _centerMapWithZoom() {
    if (_mapController != null && _currentLatLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLatLng!, zoom: 17.5),
        ),
      );
    }
  }

  Future<void> _fetchProfileImage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/upload/barber-documents/${widget.barberId}'),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final data = res['data'];
        if (data != null && data['profileImage'] != null) {
          setState(() => _profileImageUrl = data['profileImage']);
        }
      }
    } catch (e) {
      debugPrint("Error al cargar foto: $e");
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMapSection(),
          BarberServicesScreen(barberId: widget.barberId),
          BarberAppointmentsScreen(
            barberId: widget.barberId,
            barberName: widget.barberName,
            barberState: _barberState,
          ),
          BarberStoreScreen(barberId: widget.barberId),
          const SizedBox(),
        ],
      ),
      bottomNavigationBar: LiquidGlassBar(
        currentIndex: _selectedIndex,
        barberId: widget.barberId,
        barberName: widget.barberName,
        onTap: (index) {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BarberProfileScreen(
                  barberId: widget.barberId,
                  barberName: widget.barberName,
                  onBack: () => Navigator.pop(context),
                ),
              ),
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildMapSection() {
    return Stack(
      children: [
        _currentLatLng == null
            ? const Center(child: CircularProgressIndicator())
            : AppleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng!,
                  zoom: 16,
                ),
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),
        Positioned(
          right: 20,
          bottom: 225,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: _centerMapWithZoom,
            child: const Icon(Icons.my_location, color: Color(0xFFFD2424)),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(),
              _buildLocationCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBarberAvatar(),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bienvenido ${widget.barberName}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF242424),
                    ),
                  ),
                  const Text(
                    "Selecciona tu disponibilidad",
                    style: TextStyle(color: Color(0xFF242424), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          ListenableBuilder(
            listenable: _barberState,
            builder: (context, _) => Row(
              children: [
                Switch(
                  value: _barberState.isAvailable,
                  onChanged: (v) => _barberState.toggleDisponibilidad(
                    v,
                    lat: _currentLatLng?.latitude,
                    lng: _currentLatLng?.longitude,
                  ),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.green,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _barberState.isAvailable ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _barberState.modoTexto,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF242424),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.redAccent, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tu Ubicación actual",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  _realAddress,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
        image: _profileImageUrl != null
            ? DecorationImage(
                image: NetworkImage('$baseUrl$_profileImageUrl'),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _profileImageUrl == null
          ? const Icon(Icons.person, color: Colors.grey)
          : null,
    );
  }
}
