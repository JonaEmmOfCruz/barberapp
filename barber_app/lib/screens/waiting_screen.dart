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

class _WaitingScreenState extends State<WaitingScreen> {
  Timer? _pollingTimer;
  String _statusMessage = "Buscando barbero cercano...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    // Primera consulta inmediata
    _checkRequestStatus();

    // Luego cada 3 segundos
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

        setState(() {
          _statusMessage = _getStatusMessage(estado);
        });

        // Si ya no está "buscando", cancelamos el polling y navegamos
        if (estado != 'buscando') {
          _pollingTimer?.cancel();
          // Aquí puedes navegar a la pantalla de detalle del servicio o asignación
          _navigateToNextScreen(data);
        }
      } else {
        // Si falla, mostramos error pero seguimos intentando
        setState(() {
          _statusMessage = "Verificando conexión...";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error de conexión. Reintentando...";
      });
    }
  }

  String _getStatusMessage(String estado) {
    switch (estado) {
      case 'buscando':
        return "Buscando barbero cercano...";
      case 'barbero_asignado':
        return "¡Barbero asignado!";
      case 'en_camino':
        return "Tu barbero va en camino...";
      default:
        return "Procesando solicitud...";
    }
  }

  void _navigateToNextScreen(Map<String, dynamic> requestData) {
    // Ejemplo: navegar a una pantalla de detalle con los datos del barbero
    // Reemplaza con tu pantalla real (por ejemplo BarberAssignedScreen)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Servicio Confirmado")),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 20),
                Text("Estado: ${requestData['estado']}"),
                const SizedBox(height: 10),
                Text("ID Solicitud: ${widget.serviceRequestId}"),
                // Aquí puedes mostrar más información del barbero
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 30),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "ID: ${widget.serviceRequestId}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                // Botón para cancelar (opcional)
                TextButton(
                  onPressed: () {
                    _pollingTimer?.cancel();
                    Navigator.pop(context); // Vuelve a la pantalla anterior
                  },
                  child: const Text("Cancelar búsqueda"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}