import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;

const _kAzul      = Color(0xFF0D3FA6);
const _kAzulMedio = Color(0xFF1A5FD4);
const _kNavy      = Color(0xFF1A1A2E);
const _kBlanco    = Colors.white;
const _kFondo     = Color(0xFFF0F4FF);

const _kGoogleApiKey = 'AIzaSyApZq1LxHWq1t88Mbqt2R3UmzX9VUEFaBs';

class ChangeLocationScreen extends StatefulWidget {
  final String initialAddress;
  final LatLng? initialLocation;
  final String? userId;

  const ChangeLocationScreen({
    super.key,
    required this.initialAddress,
    this.initialLocation,
    this.userId,
  });

  @override
  State<ChangeLocationScreen> createState() => _ChangeLocationScreenState();
}

class _ChangeLocationScreenState extends State<ChangeLocationScreen> {
  late String _currentAddress;
  late LatLng  _currentLatLng;
  final TextEditingController _addressController = TextEditingController();
  AppleMapController? _mapController;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.initialAddress;
    _currentLatLng  = widget.initialLocation ?? const LatLng(20.7203, -103.3855);
    _addressController.text = _currentAddress;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _result => {
    'direccion': _currentAddress,
    'lat':       _currentLatLng.latitude,
    'lng':       _currentLatLng.longitude,
  };

  // ── Google Places Autocomplete ────────────────────────────────────
  Future<List<Map<String, dynamic>>> _getSugerencias(String query) async {
    if (query.length < 3) return [];
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:mx'
        '&location=20.7203,-103.3855'
        '&radius=30000'
        '&language=es'
        '&key=$_kGoogleApiKey',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return [];
      final data        = json.decode(res.body);
      final predictions = data['predictions'] as List? ?? [];
      return predictions.map<Map<String, dynamic>>((p) => {
        'descripcion': p['description'] as String,
        'placeId':     p['place_id']    as String,
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Place Details → coordenadas ───────────────────────────────────
  Future<void> _getLatLngFromPlaceId(String placeId, String descripcion) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_kGoogleApiKey',
      );
      final res  = await http.get(url);
      final data = json.decode(res.body);
      final loc  = data['result']['geometry']['location'];
      final newLatLng = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      setState(() {
        _currentLatLng          = newLatLng;
        _currentAddress         = descripcion;
        _addressController.text = descripcion;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 17));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación')));
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ── Reverse geocoding al mover pin ────────────────────────────────
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p    = placemarks.first;
        final addr = '${p.street}, ${p.locality}';
        setState(() {
          _currentAddress         = addr;
          _currentLatLng          = position;
          _addressController.text = addr;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────
          Positioned.fill(
            child: AppleMap(
              initialCameraPosition: CameraPosition(target: _currentLatLng, zoom: 15),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              onCameraMove: (pos) => _currentLatLng = pos.target,
              onCameraIdle: () => _getAddressFromLatLng(_currentLatLng),
            ),
          ),

          // ── Pin central ───────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kNavy,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]),
                    child: const Icon(Icons.location_on_rounded,
                      color: _kBlanco, size: 24)),
                  const SizedBox(height: 4),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _kNavy.withOpacity(0.3),
                      shape: BoxShape.circle)),
                ],
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context, _result),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _kBlanco,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8)
                      ]),
                    child: const Icon(Icons.arrow_back_ios_new,
                      color: _kNavy, size: 16)),
                ),
                const SizedBox(width: 12),
                const Text('Seleccionar ubicación',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: _kNavy)),
              ]),
            ),
          ),

          // ── Panel búsqueda ────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.fromLTRB(
                16, 0, 16,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 12
                    : 32,
              ),
              decoration: BoxDecoration(
                color: _kBlanco,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4))
                ]),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Dirección actual (del pin) ────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.location_on_rounded,
                          color: _kAzulMedio, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_currentAddress,
                            style: const TextStyle(
                              fontSize: 12, color: _kNavy,
                              fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                        if (_isSearching)
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kAzulMedio)),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── Buscador con Google Places ────────────
                    TypeAheadField<Map<String, dynamic>>(
                      controller: _addressController,
                      suggestionsCallback: _getSugerencias,
                      builder: (context, controller, focusNode) => TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Buscar dirección...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                            color: _kAzulMedio, size: 20),
                          suffixIcon: controller.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => controller.clear(),
                                  child: const Icon(Icons.close_rounded,
                                    color: Colors.grey, size: 18))
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8F9FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E8FF), width: 0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E8FF), width: 0.5)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _kAzulMedio, width: 1)),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14)),
                      ),
                      itemBuilder: (context, sugerencia) => ListTile(
                        dense: true,
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.location_on_outlined,
                            color: _kAzulMedio, size: 16)),
                        title: Text(sugerencia['descripcion'],
                          style: const TextStyle(
                            fontSize: 13, color: _kNavy,
                            fontWeight: FontWeight.w500)),
                      ),
                      onSelected: (sugerencia) {
                        _getLatLngFromPlaceId(
                          sugerencia['placeId'],
                          sugerencia['descripcion'],
                        );
                        FocusScope.of(context).unfocus();
                      },
                      decorationBuilder: (context, child) => Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: child,
                      ),
                      offset: const Offset(0, -8),
                      constraints: const BoxConstraints(maxHeight: 200),
                    ),
                    const SizedBox(height: 16),

                    // ── Botón confirmar ───────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _result),
                        icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: _kBlanco),
                        label: const Text('CONFIRMAR UBICACIÓN',
                          style: TextStyle(
                            color: _kBlanco, fontWeight: FontWeight.bold,
                            fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
