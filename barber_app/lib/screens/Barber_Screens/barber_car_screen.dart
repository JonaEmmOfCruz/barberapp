import 'package:flutter/material.dart';

class BarberCartScreen extends StatelessWidget {
  const BarberCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context), // Regresa a la Tienda
        ),
        title: const Text(
          "Mi Carrito",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // LISTA DE PRODUCTOS 
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 2, // Ejemplo
              itemBuilder: (context, index) => _buildCartItem(),
            ),
          ),
          
          // RESUMEN Y BOTÓN DE PAGO
          _buildCheckoutSection(),
        ],
      ),
    );
  }

  Widget _buildCartItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.image, color: Colors.red),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Gel Gorilla", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("\$150.00 MXN", style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("\$300.00 MXN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFD4A4A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Confirmar Pedido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}