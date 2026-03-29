import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:snackup/theme/app_colors.dart';
import 'package:snackup/theme/app_text.dart';

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  // ==========================================
  // CONTROLES DE UI Y ESTADO
  // ==========================================
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late String _chatId;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  bool _isGeminiInitialized = false;
  bool _isTyping = false;
  bool _hasError = false;

  // ==========================================
  // VARIABLES DE IA Y DATOS
  // ==========================================
  late GenerativeModel _model;
  late ChatSession _chatSession;
  List<Map<String, dynamic>> _availableProducts = [];

  // ==========================================
  // 🔑 PON TU API KEY AQUÍ (NUNCA LA COMPARTAS)
  // ==========================================
  final String apiKey = 'AIzaSyDNTP9CIJs4Uc9DOeg9yxo-vd_LP3i0FjM'; 

  @override
  void initState() {
    super.initState();
    if (_userId.isNotEmpty) {
      _chatId = 'global_$_userId';
      _initializeChatAndAI();
    } else {
      setState(() => _hasError = true);
    }
  }

  // ==========================================
  // 1. INICIALIZACIÓN DE LA IA Y CONTEXTO
  // ==========================================
  Future<void> _initializeChatAndAI() async {
    try {
      if (apiKey.isEmpty || apiKey.contains('TU_NUEVA')) {
        setState(() => _hasError = true);
        return;
      }

      // 1.1 Preparar documento de chat en Firestore
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        await chatRef.set({
          'userId': _userId,
          'type': 'global_assistant',
          'status': 'bot_active',
          'lastUpdate': FieldValue.serverTimestamp(),
        });
      }

      // 1.2 Obtener contexto del campus (Negocios y Menú)
      final businessesSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('isOpen', isEqualTo: true)
          .get();
          
      Map<String, String> businessNames = {
        for (var doc in businessesSnapshot.docs) doc.id: doc.data()['name'] ?? 'Local'
      };

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('isAvailable', isEqualTo: true)
          .get();
      
      // GUARDAMOS EL NOMBRE DEL LOCAL DENTRO DEL PRODUCTO PARA DESEMPATAR
      _availableProducts = productsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['productId'] = doc.id; 
        data['businessName'] = businessNames[data['businessId']] ?? 'Un local';
        return data;
      }).toList();

      String menuContext = _availableProducts.map((p) {
        return "- Producto: '${p['name']}' | Precio: \$${p['price']} | Local: '${p['businessName']}'";
      }).join("\n");

      // ==========================================
      // 🛠️ HERRAMIENTAS DE FUNCTION CALLING
      // ==========================================
      final toolAccionesPedido = Tool(functionDeclarations: [
        FunctionDeclaration(
          'agregar_al_carrito',
          'Agrega un producto al carrito. REQUIERE saber de qué local es el producto.',
          Schema(
            SchemaType.object,
            properties: {
              'producto': Schema(SchemaType.string, description: 'Nombre EXACTO del producto.'),
              'local': Schema(SchemaType.string, description: 'Nombre EXACTO del local que lo vende.'),
              'cantidad': Schema(SchemaType.integer, description: 'Cantidad deseada.'),
            },
            requiredProperties: ['producto', 'local', 'cantidad'],
          ),
        ),
        FunctionDeclaration(
          'crear_orden_directa',
          'Envía un pedido directo a cocina (bypass carrito). REQUIERE producto, local, cantidad, método de pago y hora.',
          Schema(
            SchemaType.object,
            properties: {
              'producto': Schema(SchemaType.string, description: 'Nombre EXACTO del producto.'),
              'local': Schema(SchemaType.string, description: 'Nombre EXACTO del local que lo vende.'),
              'cantidad': Schema(SchemaType.integer, description: 'Cantidad deseada.'),
              'metodo_pago': Schema(SchemaType.string, description: 'Método de pago (Efectivo, Tarjeta, Vale).'),
              'hora_recogida': Schema(SchemaType.string, description: 'Hora en formato HH:MM o la palabra "ahora".'),
            },
            requiredProperties: ['producto', 'local', 'cantidad', 'metodo_pago', 'hora_recogida'],
          ),
        )
      ]);

      // 1.4 Configurar el Modelo
      _model = GenerativeModel(
        model: 'gemini-2.5-flash', // O el modelo que estés usando
        apiKey: apiKey,
        tools: [toolAccionesPedido],
        systemInstruction: Content.system('''
          Eres "SnackBot", el asistente virtual de la app SnackUp UTSJR.
          MENÚ DISPONIBLE:
          $menuContext

          REGLAS ULTRA IMPORTANTES:
          1. Habla como universitario, usa emojis, sé amable y directo.
          2. DESEMPATE DE LOCALES: Si el usuario te pide un producto que venden VARIOS locales (ej. "Torta"), ANTES de usar una herramienta DEBES preguntarle: "¿De cuál local la quieres? Tengo en Local A y Local B".
          3. NUNCA asumas el local si hay varios con el mismo producto.
          4. Si piden comida sin decir cómo pagan ni a qué hora, PREGÚNTALES: "¿Lo agrego al carrito o lo pedimos directo a cocina? (Si es directo dime a qué hora pasas y si pagas en Efectivo/Tarjeta/Vale)".
          5. Si te dicen que lo agregues al carrito, usa 'agregar_al_carrito'.
          6. Si te dan producto, local, pago y hora, usa 'crear_orden_directa'.
          7. SOPORTE HUMANO: Si el usuario tiene una queja o quiere hablar con un cocinero, dile: "Para hablar directamente con la cocina, ve a la pestaña 'Mis Pedidos', selecciona tu orden y abre el Chat Directo con el local".
          8. No inventes productos ni precios que no estén en el menú.
        '''),
      );

      _chatSession = _model.startChat();
      setState(() => _isGeminiInitialized = true);

    } catch (e) {
      debugPrint("Error inicializando IA: $e");
      setState(() => _hasError = true);
    }
  }

  // ==========================================
  // 2. LÓGICA DE MENSAJES Y HERRAMIENTAS
  // ==========================================
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isGeminiInitialized) return;

    _messageController.clear();
    setState(() => _isTyping = true);

    try {
      // Guardar mensaje del usuario
      await _saveMessageToFirestore(text, 'user');
      _scrollToBottom();

      // Consultar a Gemini
      final response = await _chatSession.sendMessage(Content.text(text));
      String botReply = response.text?.trim() ?? '';

      // ¿Gemini decidió usar una herramienta?
      if (response.functionCalls.isNotEmpty) {
        for (final call in response.functionCalls) {
          botReply = await _handleFunctionCall(call);
        }
      }

      // Guardar respuesta final del bot
      if (botReply.isNotEmpty) {
        await _saveMessageToFirestore(botReply, 'bot');
      }

    } catch (e) {
      debugPrint('Error en el chat: $e');
      await _saveMessageToFirestore('Uy, tuve un cortocircuito 🔌 Revisa tu conexión a internet e intenta de nuevo.', 'system');
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  Future<String> _handleFunctionCall(FunctionCall call) async {
    final funcName = call.name;
    final args = call.args;
    
    final productoNombre = args['producto']?.toString().toLowerCase().trim() ?? '';
    final localNombre = args['local']?.toString().toLowerCase().trim() ?? '';
    final cantidad = (args['cantidad'] as num?)?.toInt() ?? 1;

    // 2.1 Buscar producto EXACTO por nombre Y local
    Map<String, dynamic>? prodTarget;
    for (var p in _availableProducts) {
      if (p['name'].toString().toLowerCase().trim() == productoNombre &&
          p['businessName'].toString().toLowerCase().trim() == localNombre) {
        prodTarget = p;
        break;
      }
    }

    // Si no lo encuentra, le pide a la IA que verifique o pregunte
    if (prodTarget == null) {
      final res = await _chatSession.sendMessage(
        Content.functionResponse(funcName, {'error': 'Producto no encontrado en ese local específico.'})
      );
      return res.text?.trim() ?? 'Uy, parece que ese local no tiene ese producto exacto. ¿Verificamos el nombre?';
    }

    // 2.2 Ejecutar la acción según la herramienta elegida
    if (funcName == 'agregar_al_carrito') {
      await _executeAddToCart(prodTarget, cantidad);
      await _saveMessageToFirestore(
        '🛒 SISTEMA: Has agregado $cantidad x "${prodTarget['name']}" (de ${prodTarget['businessName']}) a tu carrito.', 
        'system'
      );
      
      final res = await _chatSession.sendMessage(
        Content.functionResponse(funcName, {'status': 'success'})
      );
      return res.text?.trim() ?? '¡Listo! Ya lo agregué a tu carrito. 🛒';

    } else if (funcName == 'crear_orden_directa') {
      final metodoPago = args['metodo_pago']?.toString() ?? 'Efectivo';
      final horaRecogida = args['hora_recogida']?.toString() ?? 'ahora';
      
      await _executeDirectOrder(prodTarget, cantidad, metodoPago, horaRecogida);
      await _saveMessageToFirestore(
        '🚀 SISTEMA: Orden enviada a ${prodTarget['businessName']}.\n📦 $cantidad x "${prodTarget['name']}"\n💳 $metodoPago | ⏰ $horaRecogida', 
        'system'
      );
      
      final res = await _chatSession.sendMessage(
        Content.functionResponse(funcName, {'status': 'success'})
      );
      return res.text?.trim() ?? '¡Hecho! Tu pedido ya va para la cocina de ${prodTarget['businessName']}. 🔥';
    }

    return 'Herramienta desconocida.';
  }

  // ==========================================
  // 3. OPERACIONES DE BASE DE DATOS
  // ==========================================
  Future<void> _saveMessageToFirestore(String text, String sender) async {
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').add({
      'text': text,
      'sender': sender,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _executeAddToCart(Map<String, dynamic> product, int quantity) async {
    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cart')
        .doc(product['productId']);
        
    await cartRef.set({
      'productId': product['productId'],
      'businessId': product['businessId'],
      'name': product['name'],
      'price': product['price'],
      'imageUrl': product['imageUrl'] ?? '',
      'quantity': quantity,
      'notes': 'Pedido desde Asistente IA 🤖',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _executeDirectOrder(Map<String, dynamic> product, int quantity, String paymentMethod, String pickupTime) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();
    final userData = userDoc.data() ?? {};
    
    Timestamp? pickupTimestamp;
    if (pickupTime.toLowerCase() != 'ahora') {
      try {
        final parts = pickupTime.split(':');
        if (parts.length >= 2) {
          final now = DateTime.now();
          pickupTimestamp = Timestamp.fromDate(
            DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]))
          );
        }
      } catch (_) {} 
    }

    await FirebaseFirestore.instance.collection('orders').add({
      'businessId': product['businessId'],
      'userId': _userId,
      'userDisplayName': userData['displayName'] ?? 'Estudiante UTSJR',
      'userNumeroDeControl': userData['numeroDeControl'] ?? 'N/A',
      'status': 'pending', 
      'totalPrice': (product['price'] ?? 0.0) * quantity,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledPickupTime': pickupTimestamp,
      'items': [
        {
          'productId': product['productId'],
          'name': product['name'],
          'quantity': quantity,
          'price': product['price'],
          'notes': 'Pedido Express vía IA 🤖',
        }
      ],
    });
  }

  // ==========================================
  // 4. INTERFAZ GRÁFICA (UI)
  // ==========================================
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollController.animateTo(
          0.0, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('SnackBot IA')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al conectar con la IA.\nVerifica tu API Key o conexión a internet.', 
              textAlign: TextAlign.center, 
              style: AppText.body.copyWith(color: AppColors.error)
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Asistente SnackUp'),
            Text(
              _isGeminiInitialized ? '🤖 En línea - Tomando pedidos' : 'Conectando cerebro...',
              style: AppText.notes.copyWith(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 1,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data?.docs ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.primary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            '¡Escribe "Hola" o pídeme tu comida favorita!', 
                            textAlign: TextAlign.center, 
                            style: AppText.body.copyWith(color: AppColors.textSecondary)
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),
          
          if (_isTyping) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SnackBot está procesando tu petición...', 
                  style: AppText.notes.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)
                ),
              ),
            ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['sender'] == 'user';
    final bool isSystem = msg['sender'] == 'system';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: AppColors.success.withOpacity(0.5))
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg['text'] ?? '', 
                  style: AppText.notes.copyWith(color: AppColors.success, fontWeight: FontWeight.w700), 
                  textAlign: TextAlign.left
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.componentBase,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), 
            topRight: const Radius.circular(16), 
            bottomLeft: Radius.circular(isMe ? 16 : 4), 
            bottomRight: Radius.circular(isMe ? 4 : 16)
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), 
              blurRadius: 5, 
              offset: const Offset(0, 2)
            )
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Text(
          msg['text'] ?? '', 
          style: AppText.body.copyWith(color: isMe ? Colors.white : AppColors.textPrimary)
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background, 
        border: Border(top: BorderSide(color: AppColors.borders)), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: const Offset(0, -5)
          )
        ]
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ej: Pídeme 2 tortas para las 10:30 (Efectivo)',
                  hintStyle: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppColors.componentBase,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                style: AppText.body,
                onSubmitted: (_) => _sendMessage(),
                enabled: _isGeminiInitialized,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isGeminiInitialized ? AppColors.primary : AppColors.componentBase, 
                shape: BoxShape.circle
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded, 
                  color: _isGeminiInitialized ? Colors.white : AppColors.textSecondary, 
                  size: 22
                ), 
                onPressed: _isGeminiInitialized ? _sendMessage : null
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}