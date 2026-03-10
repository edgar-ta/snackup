import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:another_stepper/another_stepper.dart';
import 'show_qr_screen.dart';
import 'rate_order_screen.dart'; 
import 'package:snackup/theme/app_colors.dart';
import 'package:snackup/theme/app_text.dart';

// 👇 1. IMPORTAMOS LA PANTALLA DE CHAT (Ajusta la ruta si es necesario)
import '../home/order_chat_screen.dart';

class ProfileOrdersScreen extends StatefulWidget {
  const ProfileOrdersScreen({super.key});

  @override
  State<ProfileOrdersScreen> createState() => _ProfileOrdersScreenState();
}

class _ProfileOrdersScreenState extends State<ProfileOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<QuerySnapshot> _allOrdersStream;
  late Stream<QuerySnapshot> _favoritesStream;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _allOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _favoritesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.borders,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: AppText.body.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Activos'),
                Tab(text: 'Historial'),
                Tab(text: 'Favoritos'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveOrdersTab(),
          _buildHistoryTab(),
          _buildFavoritesTab(),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error al cargar pedidos activos');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Cargando pedidos activos...');
        }
        
        final activeDocs = snapshot.data!.docs.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status'];
          return status == 'pending' || status == 'preparing' || status == 'ready';
        }).toList();
        
        if (activeDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions_rounded,
            title: 'No tienes pedidos activos',
            subtitle: 'Los pedidos que hagas aparecerán aquí'
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemCount: activeDocs.length,
          itemBuilder: (context, index) {
            return _buildActiveOrderCard(activeDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allOrdersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error al cargar historial');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Cargando historial...');
        }
        
        final historyDocs = snapshot.data!.docs.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status'];
          return status == 'completed' || status == 'cancelled';
        }).toList();
        
        if (historyDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_rounded,
            title: 'No hay historial de pedidos',
            subtitle: 'Tu historial de pedidos aparecerá aquí'
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: historyDocs.length,
          itemBuilder: (context, index) {
            return _buildHistoryOrderCard(historyDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _favoritesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error al cargar favoritos');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Cargando favoritos...');
        }
        
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No tienes favoritos',
            subtitle: 'Guarda tus productos favoritos para acceder rápido'
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _buildFavoriteCard(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  Widget _buildActiveOrderCard(QueryDocumentSnapshot doc) {
    final order = doc.data()! as Map<String, dynamic>;
    final String status = order['status'] ?? 'unknown';
    final String numeroDeControl = order['userNumeroDeControl'] ?? '0000';
    final double totalPrice = order['totalPrice'] ?? 0.0;
    final List<dynamic> items = order['items'] ?? [];

    int currentStep = 0;
    String statusText = 'Recibido';
    Color statusColor = AppColors.primary;
    
    if (status == 'preparing') {
      currentStep = 1;
      statusText = 'Preparando';
      statusColor = AppColors.tertiary;
    } else if (status == 'ready') {
      currentStep = 2;
      statusText = '¡Listo!';
      statusColor = AppColors.success;
    }

    List<StepperData> stepperData = [
      StepperData(
        title: StepperText("Recibido", textStyle: TextStyle(fontWeight: currentStep >= 0 ? FontWeight.bold : FontWeight.normal, color: currentStep >= 0 ? AppColors.primary : AppColors.textSecondary)),
        iconWidget: Container(width: 32, height: 32, decoration: BoxDecoration(color: currentStep >= 0 ? AppColors.primary : AppColors.componentBase, shape: BoxShape.circle), child: Icon(Icons.receipt_long_rounded, color: currentStep >= 0 ? Colors.white : AppColors.textSecondary, size: 16)),
      ),
      StepperData(
        title: StepperText("Preparando", textStyle: TextStyle(fontWeight: currentStep >= 1 ? FontWeight.bold : FontWeight.normal, color: currentStep >= 1 ? AppColors.tertiary : AppColors.textSecondary)),
        iconWidget: Container(width: 32, height: 32, decoration: BoxDecoration(color: currentStep >= 1 ? AppColors.tertiary : AppColors.componentBase, shape: BoxShape.circle), child: Icon(Icons.restaurant_rounded, color: currentStep >= 1 ? Colors.white : AppColors.textSecondary, size: 16)),
      ),
      StepperData(
        title: StepperText("¡Listo!", textStyle: TextStyle(fontWeight: currentStep >= 2 ? FontWeight.bold : FontWeight.normal, color: currentStep >= 2 ? AppColors.success : AppColors.textSecondary)),
        iconWidget: Container(width: 32, height: 32, decoration: BoxDecoration(color: currentStep >= 2 ? AppColors.success : AppColors.componentBase, shape: BoxShape.circle), child: Icon(Icons.check_circle_rounded, color: currentStep >= 2 ? Colors.white : AppColors.textSecondary, size: 16)),
      ),
    ];

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: AppText.notes.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
                ),
                Text('\$${totalPrice.toStringAsFixed(2)}', style: AppText.h3.copyWith(color: AppColors.success, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            _buildOrderItemsSummary(items),
            const SizedBox(height: 16),
            AnotherStepper(
              stepperList: stepperData,
              stepperDirection: Axis.horizontal,
              iconWidth: 32,
              iconHeight: 32,
              activeBarColor: AppColors.primary,
              inActiveBarColor: AppColors.borders,
              activeIndex: currentStep,
              barThickness: 3,
              scrollPhysics: const NeverScrollableScrollPhysics(),
            ),
            const SizedBox(height: 20),

            // 👇 2. AQUÍ ESTÁ LA MAGIA DEL CHAT Y EL QR JUNTOS
            Row(
              children: [
                // Botón de Chat siempre visible en pedidos activos
                Expanded(
                  flex: status == 'ready' ? 1 : 2, // Se adapta si está el QR o no
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => OrderChatScreen(
                            orderId: doc.id,
                            isBusiness: false, // FALSE porque somos el estudiante
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primary),
                    label: Text('Chat', style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                
                // Botón de QR (Solo cuando esté listo)
                if (status == 'ready') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => ShowQrScreen(
                              orderId: doc.id,
                              qrData: numeroDeControl,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text('Mostrar QR', style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // 👆 FIN DE LOS BOTONES
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOrderCard(QueryDocumentSnapshot doc) {
    final order = doc.data()! as Map<String, dynamic>;
    final String status = order['status'] ?? 'unknown';
    final double totalPrice = order['totalPrice'] ?? 0.0;
    final List<dynamic> items = order['items'] ?? [];
    final Timestamp? createdAt = order['createdAt'] as Timestamp?;
    final String businessId = order['businessId'] ?? '';

    final bool isCompleted = status == 'completed';
    final Color statusColor = isCompleted ? AppColors.success : AppColors.error;
    final String statusText = isCompleted ? 'Completado' : 'Cancelado';
    final IconData statusIcon = isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusText, style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('\$${totalPrice.toStringAsFixed(2)}', style: AppText.body.copyWith(color: AppColors.textSecondary)),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(_formatDate(createdAt.toDate()), style: AppText.notes.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.replay_rounded, color: AppColors.primary, size: 20),
                    ),
                    tooltip: 'Volver a Pedir',
                    onPressed: () => _reorder(context, items),
                  ),
                if (isCompleted)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                    ),
                    tooltip: 'Calificar Pedido',
                    onPressed: () => _rateOrder(context, doc.id, businessId),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _rateOrder(BuildContext context, String orderId, String businessId) {
    FirebaseFirestore.instance.collection('businesses').doc(businessId).get().then((businessDoc) {
      final businessName = businessDoc.data()?['name'] ?? 'El Negocio';
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => RateOrderScreen(orderId: orderId, businessId: businessId, businessName: businessName)),
      );
    }).catchError((error) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => RateOrderScreen(orderId: orderId, businessId: businessId, businessName: 'El Negocio')),
      );
    });
  }

  Widget _buildFavoriteCard(QueryDocumentSnapshot doc) {
    final fav = doc.data()! as Map<String, dynamic>;
    final String name = fav['name'] ?? 'Producto';
    final String notes = fav['notes'] ?? '';
    final String imageUrl = fav['imageUrl'] ?? '';
    final double price = fav['price'] ?? 0.0;

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.componentBase),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/100',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: AppColors.componentBase, child: Icon(Icons.fastfood_rounded, color: AppColors.textSecondary.withOpacity(0.4), size: 24)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('\$${price.toStringAsFixed(2)}', style: AppText.notes.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notes, style: AppText.notes.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 20),
              ),
              tooltip: 'Añadir al Carrito',
              onPressed: () => _addFavoriteToCart(context, doc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsSummary(List<dynamic> items) {
    final totalItems = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
    final itemsSummary = items.map((item) => '${item['quantity']}x ${item['name']}').take(2).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resumen del Pedido', style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(itemsSummary, style: AppText.body.copyWith(color: AppColors.textPrimary)),
        if (items.length > 2) ...[
          const SizedBox(height: 4),
          Text('+ ${items.length - 2} productos más', style: AppText.notes.copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 4),
        Text('$totalItems productos en total', style: AppText.notes.copyWith(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Future<void> _reorder(BuildContext context, List<dynamic> items) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || items.isEmpty) return;

    try {
      final cartRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('cart');
      final productsRef = FirebaseFirestore.instance.collection('products');
      final batch = FirebaseFirestore.instance.batch();
      int itemsAdded = 0;

      for (var item in items) {
        if (item is Map<String, dynamic> && item.containsKey('productId')) {
          final productDoc = await productsRef.doc(item['productId']).get();
          if (productDoc.exists && (productDoc.data()?['isAvailable'] ?? false)) {
            final productData = productDoc.data()!;
            final docRef = cartRef.doc(item['productId']);
            batch.set(docRef, {
              'productId': item['productId'],
              'businessId': productData['businessId'],
              'name': item['name'],
              'price': item['price'],
              'imageUrl': productData['imageUrl'] ?? '',
              'quantity': item['quantity'],
              'notes': item['notes'] ?? '',
              'addedAt': FieldValue.serverTimestamp(),
            });
            itemsAdded++;
          }
        }
      }

      if (itemsAdded > 0) {
        await batch.commit();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$itemsAdded item(s) añadidos al carrito!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('No se pudo reordenar. Productos no disponibles.'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _addFavoriteToCart(BuildContext context, DocumentSnapshot doc) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final favData = doc.data()! as Map<String, dynamic>;
    final productId = favData['productId'];
    if (productId == null) return;

    try {
      final cartRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('cart').doc(productId);
      final productDoc = await FirebaseFirestore.instance.collection('products').doc(productId).get();

      if (!productDoc.exists || !(productDoc.data()?['isAvailable'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Producto no disponible.'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
        return;
      }
      final productData = productDoc.data()!;

      await cartRef.set({
        'productId': productId,
        'businessId': favData['businessId'],
        'name': favData['name'],
        'price': productData['price'],
        'imageUrl': favData['imageUrl'] ?? '',
        'quantity': 1,
        'notes': favData['notes'] ?? '',
        'addedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${favData['name']}" al carrito.'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  Widget _buildErrorState(String message) {
    return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error.withOpacity(0.7)), const SizedBox(height: 16), Text(message, style: AppText.h3.copyWith(color: AppColors.textPrimary), textAlign: TextAlign.center)])));
  }

  Widget _buildLoadingState(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: AppColors.primary), const SizedBox(height: 16), Text(message, style: AppText.body.copyWith(color: AppColors.textSecondary))]));
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 100, height: 100, decoration: const BoxDecoration(color: AppColors.componentBase, shape: BoxShape.circle), child: Icon(icon, size: 40, color: AppColors.textSecondary.withOpacity(0.5))), const SizedBox(height: 24), Text(title, style: AppText.h3.copyWith(color: AppColors.textPrimary), textAlign: TextAlign.center), const SizedBox(height: 12), Text(subtitle, style: AppText.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center)])));
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}