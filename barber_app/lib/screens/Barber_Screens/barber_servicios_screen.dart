import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BarberServicesScreen extends StatefulWidget {
  final String? barberId;
  final String? barberName;

  const BarberServicesScreen({super.key, this.barberId, this.barberName});

  @override
  State<BarberServicesScreen> createState() => _BarberServicesScreenState();
}

class _BarberServicesScreenState extends State<BarberServicesScreen> {
  String _filtroGanancias = "Hoy";
  
  // Variables para la lógica de datos
  double _totalGanancia = 0.0;
  List<dynamic> _serviciosRealizados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBarberData(); // Cargar datos al iniciar
  }

  // FUNCIÓN PARA CONECTAR AL BACKEND
  Future<void> _fetchBarberData() async {
    setState(() => _isLoading = true);
    
    // Reemplaza '192.168.1.100' por la IP real de tu computadora
    final String ipServidor = "192.168.100.19"; 
    final url = Uri.parse('http://$ipServidor:3000/api/servicios/stats/${widget.barberId}?filtro=$_filtroGanancias');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalGanancia = (data['gananciaTotal'] ?? 0).toDouble();
          _serviciosRealizados = data['servicios'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al obtener servicios: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 1. Status Bar Roja
          Container(height: 50, color: const Color.fromARGB(255, 255, 36, 36)),

          // 2. Header Rojo con el Título
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 255, 36, 36),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: const Text(
              'Mis servicios',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold, 
                fontSize: 26,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 15),

          // 3. SECCIÓN DE ESTADÍSTICAS (Ganancias + Selector)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Widget de Ganancias (DINÁMICO)
                _buildTopStat(
                  "Ganancias", 
                  " ${_totalGanancia.toStringAsFixed(2)}", 
                  const Color.fromARGB(255, 45, 201, 55), 
                  Icons.attach_money_sharp,
                  
                ),
                
                // Botón Select (Dropdown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filtroGanancias,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                      style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                      onChanged: (String? newValue) {
                        setState(() {
                          _filtroGanancias = newValue!;
                        });
                        _fetchBarberData(); // Recargar al cambiar filtro
                      },
                      items: <String>['Hoy', 'Semana', 'Mes']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. LISTA DE SERVICIOS REALIZADOS
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : _serviciosRealizados.isEmpty
              ? const Center(child: Text("No hay servicios realizados aún"))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  itemCount: _serviciosRealizados.length,
                  itemBuilder: (context, index) {
                    final servicio = _serviciosRealizados[index];
                    return _buildServiceCard(servicio);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 5),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(dynamic servicio) {
    // Extraemos datos del JSON que viene del backend
    final String serviciosRealizados = servicio['servicios'] ?? "Servicio general";
    final double costo = (servicio['ganancia'] ?? 0.0).toDouble();
    final int duracion = servicio['duracionTotalMinutos'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBEB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 35, color: Color(0xFFFD4A4A)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cliente Atendido", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(serviciosRealizados, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _smallInfo(Icons.payments_outlined, "\$${costo.toStringAsFixed(2)}"),
                    const SizedBox(width: 15),
                    _smallInfo(Icons.timer_outlined, "$duracion min"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFFD4A4A)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}