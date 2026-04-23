import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:barber_app/config/app_config.dart';

class BookingScreen extends StatefulWidget {
  final dynamic barber;
  final String userId; // Ahora se recibe por constructor

  const BookingScreen({
    super.key,
    required this.barber,
    required this.userId, // Requerido en el constructor
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  String? selectedTime;
  bool isSaving = false;

  final List<String> timeSlots = [
    "09:00 AM",
    "10:00 AM",
    "11:00 AM",
    "12:00 PM",
    "01:00 PM",
    "02:00 PM",
    "03:00 PM",
    "04:00 PM",
    "05:00 PM",
    "09:00 PM",
  ];

  List<DateTime> _getWeekDays() {
    DateTime now = DateTime.now();
    // Ajuste para obtener los días de la semana actual
    DateTime firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
      7,
      (index) => firstDayOfWeek.add(Duration(days: index)),
    );
  }

  Future<void> _confirmBooking() async {
    setState(() => isSaving = true);

    final Map<String, dynamic> data = {
      'userId': widget.userId,
      'barberId':
          widget.barber['_id'] ??
          widget.barber['id'], // Prueba ambos por si acaso
      'fecha': selectedDate!.toIso8601String(),
      'hora': selectedTime,
    };

    print(
      "Enviando datos: ${jsonEncode(data)}",
    ); // Revisa esto en la consola de VS Code

    try {
      final response = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/api/reservas/create',
        ), // Verifica que la ruta sea /reservas/
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        _showSuccessAnimation();
      } else {
        // Muestra el error real que responde el servidor
        final errorData = jsonDecode(response.body);
        print("Error del servidor: ${errorData['error']}");

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${errorData['error']}")));
      }
    } catch (e) {
      print("Error de red: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de check en lugar de Lottie
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green[600],
                    size: 80,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "¡Cita Confirmada!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tu barbero te espera.\nSe ha registrado con éxito.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Cierra el diálogo
                      Navigator.pop(context); // Regresa a la pantalla anterior
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "ENTENDIDO",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _getWeekDays();
    final String name = widget.barber['nombre'] ?? 'Barbero';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Reserva con $name",
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "Selecciona el día",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: days.length,
              itemBuilder: (context, index) {
                DateTime day = days[index];
                bool isPast = day.isBefore(
                  DateTime.now().subtract(const Duration(days: 1)),
                );
                bool isSelected =
                    selectedDate != null &&
                    selectedDate!.day == day.day &&
                    selectedDate!.month == day.month;

                return GestureDetector(
                  onTap: isPast
                      ? null
                      : () => setState(() => selectedDate = day),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue[700]
                          : (isPast ? Colors.grey[200] : Colors.blue[50]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day).toUpperCase(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isPast ? Colors.grey : Colors.blue[700]),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isPast ? Colors.grey : Colors.black),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "Selecciona la hora",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: timeSlots.length,
              itemBuilder: (context, index) {
                String time = timeSlots[index];
                bool isSelected = selectedTime == time;

                return GestureDetector(
                  onTap: () => setState(() => selectedTime = time),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[700] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        time,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                    (selectedDate == null || selectedTime == null || isSaving)
                    ? null
                    : () => _confirmBooking(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "CONFIRMAR CITA",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
