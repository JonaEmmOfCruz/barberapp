import 'package:flutter/material.dart';
import 'package:barber_app/models/cart_item.dart';

class UserCartScreen extends StatefulWidget {
  const UserCartScreen({super.key});

  @override
  State<UserCartScreen> createState() => _UserCartScreenState();
}

class _UserCartScreenState extends State<UserCartScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Mi carrito", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: globalCart.isEmpty
          ? const Center(child: Text("El carrito está vacío"))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: globalCart.length,
              itemBuilder: (context, index) {
                final item = globalCart[index];
                return _buildCartItem(item, index);
              },
            ),
      bottomSheet: globalCart.isEmpty ? null : _buildTotalBar(),
    );
  }

  Widget _buildCartItem(CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFE8F2FF), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: const Color(0xFFD0E2FF), borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.image, color: Colors.blue),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Cantidad: ${item.quantity}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                GestureDetector(
                  onTap: () => setState(() => globalCart.removeAt(index)),
                  child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ),
          ),
          Text("\$${(item.price * item.quantity).toStringAsFixed(2)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTotalBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Total: \$${cartTotal.toStringAsFixed(2)} MXN", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("Pagar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}