import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:barber_app/config/app_config.dart';

class WaitingScreen extends StatefulWidget {
  final String serviceRequestId;

  const WaitingScreen({super.key, required this.serviceRequestId});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> with TickerProviderStateMixin {
  Timer? _pollingTimer;
  String _statusMessage = "Buscando Barbero cerca de ti...";
  String _estadoActual = 'buscando';
  
  // Eliminamos 'late' y usamos controladores opcionales para evitar el crash
  AnimationController? _bikeJumpController;
  Animation<double>? _bikeJumpAnimation;

  AnimationController? _backgroundScrollController;
  Animation<double>? _backgroundScrollAnimation;

  final List<IconData> _backgroundIcons = [
    Icons.park,         
    Icons.terrain,      
    Icons.park,
    Icons.terrain,
    Icons.park,
    Icons.terrain,
  ];

  @override
  void initState() {
    super.initState();
    
    // 1. Inicialización de la Moto (Eje Y)
    _bikeJumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _bikeJumpAnimation = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _bikeJumpController!, curve: Curves.easeInOut),
    );

    _bikeJumpController!.repeat(reverse: true);

    // 2. Inicialización del Fondo (Eje X)
    _backgroundScrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _backgroundScrollAnimation = Tween<double>(begin: 0, end: -1.0).animate(
      CurvedAnimation(parent: _backgroundScrollController!, curve: Curves.linear),
    );
    
    if (_estadoActual == 'buscando') {
      _backgroundScrollController!.repeat();
    }
    
    _startPolling();
  }

  void _startPolling() {
    _checkRequestStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkRequestStatus();
    });
  }

  Future<void> _checkRequestStatus() async {
    final url = '${AppConfig.baseUrl}/api/service-requests/${widget.serviceRequestId}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final estado = data['estado'] ?? 'buscando';

        if (mounted) {
          setState(() {
            _estadoActual = estado;
            _statusMessage = _getStatusMessage(estado);
            
            if (_estadoActual != 'buscando') {
              _backgroundScrollController?.stop();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error polling: $e");
    }
  }

  String _getStatusMessage(String estado) {
    if (estado == 'buscando') return "Buscando Barbero cerca de ti...";
    return "Encontramos un barbero cerca de ti...";
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _bikeJumpController?.dispose();
    _backgroundScrollController?.dispose();
    super.dispose();
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: isSelected ? Colors.blue[600] : Colors.grey[400]),
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

  Widget _buildBackgroundRow(double width) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _backgroundIcons.map((icon) => Icon(icon, size: 35, color: Colors.black)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // Validación de seguridad: Si las animaciones no están listas, mostrar cargando
    if (_bikeJumpAnimation == null || _backgroundScrollAnimation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _estadoActual != 'buscando' ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 70),
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Container(width: 220, height: 1.5, color: Colors.grey[300]),
                const SizedBox(height: 120),

                SizedBox(
                  width: screenWidth,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Fondo con árboles y pinas (Icons.terrain) moviéndose a la izquierda
                      if (_estadoActual == 'buscando')
                        AnimatedBuilder(
                          animation: _backgroundScrollAnimation!,
                          builder: (context, child) {
                            return Positioned(
                              left: _backgroundScrollAnimation!.value * screenWidth,
                              bottom: 10,
                              child: Row(
                                children: [
                                  _buildBackgroundRow(screenWidth),
                                  _buildBackgroundRow(screenWidth),
                                ],
                              ),
                            );
                          },
                        ),

                      if (_estadoActual != 'buscando')
                        const Positioned(
                          right: 60,
                          bottom: 10,
                          child: Icon(Icons.home, size: 55, color: Colors.black),
                        ),

                      Container(
                        height: 1.2,
                        color: Colors.black87,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                      ),
                      
                      // Moto estática brincando en el centro
                      AnimatedBuilder(
                        animation: _bikeJumpAnimation!,
                        builder: (context, child) {
                          return Positioned(
                            bottom: 2 + _bikeJumpAnimation!.value,
                            child: const Icon(Icons.motorcycle, size: 40, color: Colors.black),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
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
            _buildNavItem(Icons.storefront, "BarberShop", false), 
            _buildNavItem(Icons.person, "Perfil", false),
          ],
        ),
      ),
    );
  }
}