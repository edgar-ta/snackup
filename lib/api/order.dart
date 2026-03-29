import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snackup/types.dart';

Stream<OrderDetail?> getOrderDetail({
  required String orderId,
  required bool isBusiness,
}) {
  final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(orderId);
  final messageQuery = chatRef
      .collection('messages')
      .where('isBusiness', isEqualTo: !isBusiness)
      .orderBy('timestamp', descending: true)
      .limit(1);

  final controller = StreamController<OrderDetail?>.broadcast();

  DocumentSnapshot<Map<String, dynamic>>? orderSnapshot;
  DocumentSnapshot<Map<String, dynamic>>? chatSnapshot;
  QuerySnapshot<Map<String, dynamic>>? messageSnapshot;

  void emitCurrent() {
    if (orderSnapshot == null) return;

    final orderData = orderSnapshot!.data();
    if (!orderSnapshot!.exists || orderData == null) {
      controller.add(null);
      return;
    }

    bool hasNewMessages = false;
    if (chatSnapshot?.exists == true) {
      final chatData = chatSnapshot!.data();
      final lastSeenValue = isBusiness
          ? (chatData?['businessLastSeenTime'])
          : (chatData?['clientLastSeenTime']);
      final lastSeenTime = _parseDateTime(lastSeenValue);

      if (messageSnapshot?.docs.isNotEmpty == true) {
        final messageData = messageSnapshot!.docs.first.data();
        final lastMessageTime = _parseDateTime(messageData['timestamp']);
        if (lastMessageTime != null &&
            (lastSeenTime == null || lastMessageTime.isAfter(lastSeenTime))) {
          hasNewMessages = true;
        }
      }
    }

    final detail = OrderDetail.fromMap(
      orderRef.id,
      orderData,
      hasNewMessages: hasNewMessages,
      isBusiness: isBusiness,
    );

    controller.add(detail);
  }

  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  orderSub;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> chatSub;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> messageSub;

  orderSub = orderRef.snapshots().listen((snapshot) {
    orderSnapshot = snapshot;
    emitCurrent();
  }, onError: controller.addError);

  chatSub = chatRef.snapshots().listen((snapshot) {
    chatSnapshot = snapshot;
    emitCurrent();
  }, onError: controller.addError);

  messageSub = messageQuery.snapshots().listen((snapshot) {
    messageSnapshot = snapshot;
    emitCurrent();
  }, onError: controller.addError);

  controller.onCancel = () async {
    await orderSub.cancel();
    await chatSub.cancel();
    await messageSub.cancel();
  };

  return controller.stream;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

Future<void> updateOrderStatus({
  required String orderId,
  required String status,
}) async {
  final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
  final orderDoc = await orderRef.get();
  if (!orderDoc.exists) {
    throw Exception('Order not found: $orderId');
  }

  final currentStatus = orderDoc.data()?['status'] as String?;
  Map<String, dynamic> object = {'status': status};

  if (status == 'preparing' && currentStatus != 'preparing') {
    object['redeemCode'] = _generateRedeemCode();
  }

  return await orderRef.update(object);
}

String _generateRedeemCode() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
}
