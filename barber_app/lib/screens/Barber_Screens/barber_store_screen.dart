import 'package:flutter/material.dart';
import 'barber_car_screen.dart'; // Verifica que el nombre del archivo sea correcto

class BarberStoreScreen extends StatefulWidget {
  final String? barberId;
  final String? barberName;

  const BarberStoreScreen({super.key, this.barberId, this.barberName});

  @override
  State<BarberStoreScreen> createState() => _BarberStoreScreenState();
}

class _BarberStoreScreenState extends State<BarberStoreScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, 
      child: Column(
        children: [
          // 1. Status Bar Roja
          Container(
            height: 50,
            color: const Color.fromARGB(255, 244, 67, 54),
          ),

          // 2. Header Rojo con Título y Carrito
          Container(
            color: const Color.fromARGB(255, 244, 67, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BarberShop',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold, 
                    fontSize: 26,
                    letterSpacing: 0.5,
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BarberCartScreen()),
                        );
                      },
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: const Text(
                          '1',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), 
                          textAlign: TextAlign.center
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // 3. Contenido Principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 120), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  
                  // --- NUEVA BARRA DE FILTROS (Categorías horizontales) ---
                  _buildCategoryFilters(),
                  
                  const SizedBox(height: 10),

                  // --- SECCIONES DE PRODUCTOS (Iniciando con Barberapp) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildCategorySection("Productos Barberapp", ["Mochila 1","Mochila 2","Mochila 3","Mochila 4", "Impermeable 1","Impermeable 2","Impermeable 3","Impermeable 4", "Silla 1","Silla 2","Silla 3","Silla 4"]),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para los botones horizontales tipo "Chips"
  Widget _buildCategoryFilters() {
    final categories = ["Promociones", "Favoritos", "Maquinas","Tijeras","Higiene","Utensilios","Estilizado","Cuidado de barba","Cuidado capilar","Skin care"];
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Botón de Menú (Hamburgesa)
            return Container(
              margin: const EdgeInsets.only(right: 10),
              width: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu, size: 20, color: Colors.black87),
            );
          }

          final name = categories[index - 1];
          bool isSelected = name == "Promociones"; // Estilo de la foto

          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFEBEB) : const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFD4A4A) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(String title, List<String> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 15, bottom: 8),
          child: Text(
            title, 
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black)
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 0, 
            mainAxisExtent: 210, 
          ),
          itemBuilder: (context, index) => _buildProductItem(products[index]),
        ),
      ],
    );
  }

  Widget _buildProductItem(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 240, 240, 240),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, color: Colors.grey, size: 40)
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red, 
            borderRadius: BorderRadius.circular(12)
          ),
          child: const Text(
            "\$000.00 MXN", 
            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name, 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
        const Text(
          "1 unidad", 
          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)
        ),
      ],
    );
  }
}