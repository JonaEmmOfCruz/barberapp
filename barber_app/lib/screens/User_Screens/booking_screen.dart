import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:barber_app/config/app_config.dart';

class BookingScreen extends StatefulWidget {
  final dynamic barber;
  final String userId;

  const BookingScreen({
    super.key,
    required this.barber,
    required this.userId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  String? selectedTime;
  bool isSaving = false;

  final List<String> timeSlots = [
    "08:00 AM", "09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM",
    "01:00 PM", "02:00 PM", "03:00 PM", "04:00 PM", "05:00 PM",
    "06:00 PM", "07:00 PM", "08:00 PM", "09:00 PM", "10:00 PM",
  ];

  List<DateTime> _getWeekDays() {
    DateTime now = DateTime.now();
    return List.generate(7, (index) => now.add(Duration(days: index)));
  }

  bool _isTimeBlocked(String slot) {
    if (selectedDate == null) return false;
    DateTime now = DateTime.now();
    if (selectedDate!.day != now.day || selectedDate!.month != now.month) return false;

    try {
      DateFormat format = DateFormat.jm(); 
      DateTime slotTime = format.parse(slot);
      DateTime fullSlotDateTime = DateTime(now.year, now.month, now.day, slotTime.hour, slotTime.minute);
      return fullSlotDateTime.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  Future<void> _confirmBooking() async {
    setState(() => isSaving = true);
    final Map<String, dynamic> data = {
      'userId': widget.userId,
      'barberId': widget.barber['_id'] ?? widget.barber['id'],
      'fecha': selectedDate!.toIso8601String(),
      'hora': selectedTime,
    };

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/reservas/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        _showSuccessAnimation();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${errorData['error']}")),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF), size: 80),
              const SizedBox(height: 20),
              const Text("¡Cita Exitosa!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("ENTENDIDO", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _getWeekDays();
    final String name = widget.barber['nombre'] ?? 'Barbero';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 15, top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Agendar cita", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1.2)),
                    Text("con $name", style: const TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Container(width: 50, height: 6, decoration: BoxDecoration(color: const Color(0xFF007AFF), borderRadius: BorderRadius.circular(10))),
                  ],
                ),
              ),
            ),

            // --- PASO 1: SELECCIONAR EL DÍA ---
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    child: Text("1. Selecciona el día", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        DateTime day = days[index];
                        bool isSelected = selectedDate?.day == day.day;
                        return GestureDetector(
                          onTap: () => setState(() { 
                            selectedDate = day; 
                            selectedTime = null; // Reiniciar hora al cambiar día
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 75,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE8F2FF),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFF007AFF).withOpacity(0.1)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(DateFormat('EEE').format(day).toUpperCase(), 
                                  style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(day.day.toString(), 
                                  style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 19)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // --- PASO 2: SELECCIONAR EL HORARIO (Solo aparece si hay un día seleccionado) ---
            if (selectedDate != null) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(30, 35, 30, 15),
                  child: Text("2. Selecciona el horario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 2.1, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      String time = timeSlots[index];
                      bool isBlocked = _isTimeBlocked(time);
                      bool isSelected = selectedTime == time;

                      return GestureDetector(
                        onTap: isBlocked ? null : () => setState(() => selectedTime = time),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isBlocked 
                                ? const Color(0xFFF2F2F7) 
                                : (isSelected ? const Color(0xFF007AFF) : const Color(0xFFE8F2FF)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              time,
                              style: TextStyle(
                                color: isBlocked 
                                    ? Colors.grey[400] 
                                    : (isSelected ? Colors.white : const Color(0xFF007AFF)),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: timeSlots.length,
                  ),
                ),
              ),
            ] else 
              // Mensaje de ayuda si no ha seleccionado día
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      "Selecciona un día para ver horarios",
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ),

            // --- BOTÓN CONFIRMAR ---
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    onPressed: (selectedDate == null || selectedTime == null || isSaving) ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      disabledBackgroundColor: Colors.grey[300],
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("CONFIRMAR CITA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}