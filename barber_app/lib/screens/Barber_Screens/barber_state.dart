import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:barber_app/config/app_config.dart';

// ─────────────────────────────────────────────
//  BarberState — Estado global compartido
//
//  Un solo objeto que vive en BarberHomeScreen
//  y se pasa a todos los screens hijos.
//  Cuando cambia, todos los widgets que lo
//  escuchan se rebuildan automáticamente.
// ─────────────────────────────────────────────

class BarberState extends ChangeNotifier {
  final String barberId;
  final String baseUrl = AppConfig.baseUrl;

  String  workMode    = 'offline';
  bool    isAvailable = false;
  bool    isWorking   = false;
  bool    cargando    = false;

  BarberState({required this.barberId});

  // ── Carga el estado desde el backend ──────
  Future<void> cargarEstado() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/disponibilidad/$barberId/estado'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        workMode    = data['workMode']    ?? 'offline';
        isAvailable = data['isAvailable'] ?? false;
        isWorking   = data['isWorking']   ?? false;
        notifyListeners(); // ← avisa a todos los widgets que escuchan
      }
    } catch (e) {
      debugPrint('BarberState.cargarEstado error: $e');
    }
  }

  // ── Toggle disponibilidad ─────────────────
  Future<void> toggleDisponibilidad(bool valor, {double? lat, double? lng}) async {
    final anterior = isAvailable;
    isAvailable = valor;
    notifyListeners(); // cambio optimista

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/disponibilidad/$barberId/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'isAvailable': valor,
          'lat': ?lat,
          'lng': ?lng,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        workMode = data['workMode'] ?? workMode;
        notifyListeners();
      } else {
        // Revertir si falló
        isAvailable = anterior;
        notifyListeners();
      }
    } catch (e) {
      isAvailable = anterior;
      notifyListeners();
      debugPrint('BarberState.toggleDisponibilidad error: $e');
    }
  }

  // ── Texto del modo actual ─────────────────
  String get modoTexto {
    switch (workMode) {
      case 'runner':  return 'Modo Runner';
      case 'agenda':  return 'Modo Agenda';
      case 'hibrido': return 'Modo Híbrido';
      default:        return 'No disponible';
    }
  }

  // ── Color del dot del badge ───────────────
  Color get modoDotColor {
    switch (workMode) {
      case 'runner':  return const Color(0xFF4ADE80);
      case 'agenda':  return const Color(0xFF4ADE80);
      case 'hibrido': return const Color(0xFFFB923C);
      default:        return const Color(0xFF9E9E9E);
    }
  }
}