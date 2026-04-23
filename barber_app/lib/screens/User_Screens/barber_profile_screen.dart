import 'package:flutter/material.dart';
import 'package:barber_app/screens/User_Screens/booking_screen.dart';

class BarberProfileScreen extends StatelessWidget {
  final dynamic barber;
  final String userId;

  const BarberProfileScreen({
    super.key,
    required this.barber,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    // Extracción de datos reales según la imagen del modelo en MongoDB
    final String name = barber['nombre'] ?? 'Sin nombre';
    final List<dynamic> servicios = barber['servicios'] ?? [];
    final List<dynamic> diasDisponibles = barber['dias'] ?? [];
    final Map<String, dynamic>? horario = barber['horario'];

    // Estos campos no aparecen en tu captura de modelo de MongoDB actual
    // Por lo tanto, se manejarán como nulos o listas vacías.
    final dynamic vehiculo = barber['vehiculo'];
    final Map<String, dynamic>? redes = barber['redes_sociales'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Perfil del barbero",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar y Nombre
            Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.person, size: 45, color: Colors.blue[600]),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        servicios.isNotEmpty
                            ? servicios.join(", ")
                            : "Servicios no especificados",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            const Text(
              "Servicios hechos por mi:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),

            // Sección de Galería (Vacía por ahora como solicitaste)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "No hay galería disponible",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "Horarios y Disponibilidad:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // Días de la semana desde el Array 'dias' de la DB
            if (diasDisponibles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildTag(
                  Icons.calendar_month,
                  "${diasDisponibles.first} - ${diasDisponibles.last}",
                ),
              ),

            // Horas desde el objeto 'horario' de la DB
            if (horario != null)
              _buildTag(
                Icons.access_time_filled,
                "${horario['apertura']} - ${horario['cierre']}",
              ),

            // Solo mostrar sección de vehículo si existe en la data
            if (vehiculo != null) ...[
              const SizedBox(height: 25),
              const Text(
                "Vehículo:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (vehiculo['marca'] != null)
                    _buildTag(Icons.directions_car, vehiculo['marca']),
                  if (vehiculo['matricula'] != null)
                    _buildTag(Icons.credit_card, vehiculo['matricula']),
                ],
              ),
            ],

            // Solo mostrar redes sociales si existen en la data
            if (redes != null) ...[
              const SizedBox(height: 25),
              const Text(
                "Redes Sociales:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: redes.entries.map((entry) {
                  return _buildSocialTag(
                    _getIconForSocial(entry.key),
                    entry.value,
                    Colors.black87,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // --- REDIRECCIÓN A BOOKING SCREEN ---
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingScreen(
                        barber: barber, // Pasamos el mapa del barbero
                        userId: userId, // Pasamos el ID del usuario
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "RESERVAR SERVICIO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTag(IconData icon, String user, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            user,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  IconData _getIconForSocial(String key) {
    switch (key.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      default:
        return Icons.link;
    }
  }
}
