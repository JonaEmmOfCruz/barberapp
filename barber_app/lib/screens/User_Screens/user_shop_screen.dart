import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:barber_app/models/cart_item.dart';
import 'user_cart_screen.dart';

// Importaciones de tus otras pantallas
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
        backgroundColor: const Color(0xFF007AFF),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- TÍTULO ESTILO SLIVER ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 40, 30, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "BarberShop",
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 50,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- CONTENIDO DE LA TIENDA ---
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSection("Gel y Ceras", ["Gel 1", "Cera 1", "Gel 2"]),
                      _buildSection("Shampoos", ["Shampoo 1", "Shampoo 2", "Shampoo 3"]),
                    ]),
                  ),
                ),
              ],
            ),

            // --- BOTÓN FLOTANTE DEL CARRITO (ARRIBA DERECHA) ---
            Positioned(
              top: 20,
              right: 20,
              child: _buildCartButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomMenu(),
    );
  }

  Widget _buildCartButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF007AFF), size: 30),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserCartScreen()),
          ).then((_) => setState(() {})),
        ),
        if (globalCart.isNotEmpty)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '${globalCart.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection(String title, List<String> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F))),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, 
            childAspectRatio: 0.65, 
            crossAxisSpacing: 12, 
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        ),
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
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF007AFF))),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _addToCart(name, 150.0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "\$150.00",
          style: TextStyle(color: Colors.blue[800], fontSize: 11, fontWeight: FontWeight.w900),
        ),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1D1D1F)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBottomMenu() {
    return Container(
      margin: const EdgeInsets.fromLTRB(35, 0, 35, 25),
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: Colors.white.withOpacity(0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navAction(Icons.home_filled, "Inicio", false, () => Navigator.pop(context)),
                _navAction(Icons.description, "Servicios", false, () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserServicesScreen()));
                }),
                _navAction(Icons.storefront, "Tienda", true, () {}),
                _navAction(Icons.person, "Perfil", false, () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserPerfilScreen()));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navAction(IconData icon, String label, bool active, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: active ? const Color(0xFF007AFF) : Colors.grey[400]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF007AFF) : Colors.grey[400], fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}