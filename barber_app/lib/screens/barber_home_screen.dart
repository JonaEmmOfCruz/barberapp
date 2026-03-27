import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';
import 'Barber_Profile_Screen.dart';

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
  AppleMapController? _mapController;
  LatLng? _currentLatLng;

  final String baseUrl = AppConfig.baseUrl;

  String _realAddress = "Obteniendo ubicación...";
  bool _isLoading = true;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoading = true);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _realAddress = "Permiso de ubicación denegado";
          _isLoading = false;
        });
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLatLng = LatLng(position.latitude, position.longitude);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];

      setState(() {
        _realAddress =
            "${place.street}, ${place.locality}, ${place.administrativeArea}";
        _isLoading = false;
      });

      _centerMapWithZoom();
    } catch (e) {
      setState(() {
        _currentLatLng = const LatLng(20.7219, -103.3911);
        _realAddress = "C. Calle #1, Zapopan, Jalisco (GPS falló)";
        _isLoading = false;
      });
      _centerMapWithZoom();
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

  Future<void> _updateAvailability(bool value) async {
    setState(() => _isAvailable = value);
    // Aquí puedes implementar la llamada a tu API si existe
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _currentLatLng == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                )
              : AppleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 16,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  child: Row(
                    children: [
                      _buildBarberAvatar(),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Bienvenido ${widget.barberName}",
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Estado dinámico
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isAvailable ? "Disponible" : "No disponible",
                                  style: const TextStyle(
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
                    ],
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.blue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Tu Ubicación actual",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _realAddress,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Divider(color: Colors.grey, height: 1),
                        const SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isAvailable ? "Disponible:" : "No Disponible:",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isAvailable
                                    ? Colors.blue
                                    : Colors.blueGrey,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.9,
                              child: Switch(
                                value: _isAvailable,
                                onChanged: _updateAvailability,
                                activeColor: Colors.white,
                                activeTrackColor: Colors.blue,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey[400],
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),

          Positioned(
            right: 20,
            top: 130,
            child: Column(
              children: [
                _iconBtn(Icons.person, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BarberProfileScreen(
                        barberId: widget.barberId,
                        barberName: widget.barberName,
                      ),
                    ),
                  );
                }, isCircle: false),
                const SizedBox(height: 12),
                _iconBtn(Icons.my_location, _centerMapWithZoom, isCircle: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberAvatar() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: const Center(child: Icon(Icons.cut, size: 35, color: Colors.blue)),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {required bool isCircle}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.blue, size: 24),
      ),
    );
  }
}
