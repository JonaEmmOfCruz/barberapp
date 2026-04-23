import 'package:flutter/material.dart';
import 'dart:ui'; // Necesario para BackdropFilter e ImageFilter
import 'package:barber_app/models/cart_item.dart';
import 'user_cart_screen.dart';

// Importaciones de tus otras pantallas para el menú
import 'package:barber_app/screens/User_Screens/user_home_screen.dart';
import 'package:barber_app/screens/User_Screens/user_services_screen.dart';
import 'package:barber_app/screens/User_Screens/user_perfil_screen.dart';

class UserShopScreen extends StatefulWidget {
  const UserShopScreen({super.key});

  @override
  State<UserShopScreen> createState() => _UserShopScreenState();
}

class _UserShopScreenState extends State<UserShopScreen> {
  void _addToCart(String name, double price) {
    setState(() {
      var existing = globalCart.where((item) => item.name == name);
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        globalCart.add(CartItem(
          id: DateTime.now().toString(),
          name: name,
          price: price,
        ));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$name añadido al carrito"), 
        duration: const Duration(milliseconds: 500),
        backgroundColor: Colors.blue[700],
      )
    );
  }

  // --- FUNCIÓN AUXILIAR DEL MENÚ ---
  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: isSelected ? Colors.blue[600] : Colors.grey[400],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, // Permite que el cuerpo se extienda detrás del menú flotante
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Quitamos flecha para usar el menú
        title: const Text(
          "BarberShop", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.blue, size: 28),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserCartScreen()),
                ).then((_) => setState(() {})),
              ),
              if (globalCart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2962FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cartCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 100), // Espacio abajo para el menú
        child: Column(
          children: [
            _buildSection("Gel y Ceras", ["Gel 1", "Cera 1", "Gel 2"]),
            _buildSection("Shampoos", ["Shampoo 1", "Shampoo 2", "Shampoo 3"]),
          ],
        ),
      ),
      // --- MENÚ INFERIOR IDÉNTICO AL HOME ---
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
        height: 65,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.blue[900]!.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  width: 1.5,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Regresa al Home
                    child: _buildNavItem(Icons.home_filled, "Inicio", false),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const UserServicesScreen()),
                      );
                    },
                    child: _buildNavItem(Icons.description, "Servicios", false),
                  ),
                  GestureDetector(
                    onTap: () => /* Ya estás aquí */ {},
                    child: _buildNavItem(Icons.storefront, "Tienda", true),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const UserPerfilScreen()),
                      );
                    },
                    child: _buildNavItem(Icons.person, "Perfil", false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 10, mainAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProductCard(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 90, width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFD0E2FF), borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.image, size: 40, color: Color(0xFF2962FF)),
            ),
            Positioned(
              bottom: 5, right: 5,
              child: GestureDetector(
                onTap: () => _addToCart(name, 150.0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF2962FF), shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
          child: const Text("\$150.00 MXN", style: TextStyle(color: Colors.white, fontSize: 8)),
        ),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }
}