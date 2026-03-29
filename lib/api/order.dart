import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snackup/types.dart';

Future<OrderDetail?> getOrderDetail({
  required String orderId,
  required bool isBusiness,
}) async {
  final orderDoc = await FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .get();

  final data = orderDoc.data();
  if (!orderDoc.exists || data == null) {
    return null;
  }

  bool hasNewMessages = false;
  final chatDoc = await FirebaseFirestore.instance
      .collection('chats')
      .doc(orderId)
      .get();

  if (chatDoc.exists) {
    final chatData = chatDoc.data();

    final lastSeenValue = isBusiness
        ? (chatData?['businessLastSeenTime'])
        : (chatData?['clientLastSeenTime']);

    final lastSeenTime = _parseDateTime(lastSeenValue);

    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .where("isBusiness", isEqualTo: !isBusiness)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (messagesSnapshot.docs.isNotEmpty) {
      final messageData = messagesSnapshot.docs.first.data();
      final lastMessageTime = _parseDateTime(messageData['timestamp']);

      if (lastMessageTime != null &&
          (lastSeenTime == null || lastMessageTime.isAfter(lastSeenTime))) {
        hasNewMessages = true;
      }
    }
  }

  OrderDetail detail = OrderDetail.fromMap(
    orderDoc.id,
    data,
    hasNewMessages: hasNewMessages,
    isBusiness: isBusiness,
  );

  return detail;
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
