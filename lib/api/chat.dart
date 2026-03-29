import 'package:cloud_firestore/cloud_firestore.dart';

/// Asegura que exista un chat de tipo 'order_support' con la
/// id de la orden solicitada
Future<
  (
    DocumentReference<Map<String, dynamic>>,
    DocumentSnapshot<Map<String, dynamic>>,
    bool wasCreated,
  )
>
ensureSupportChatExists({
  required String orderId,
  required bool isBusiness,
}) async {
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(orderId);
  FieldValue? timeOfClient;
  FieldValue? timeOfBusiness;

  if (isBusiness) {
    timeOfClient = null;
    timeOfBusiness = FieldValue.serverTimestamp();
  } else {
    timeOfClient = FieldValue.serverTimestamp();
    timeOfBusiness = null;
  }

  final chatDoc = await chatRef.get();
  if (!chatDoc.exists) {
    await chatRef.set({
      'orderId': orderId,
      'type': 'order_support',
      'createdAt': FieldValue.serverTimestamp(),
      'clientLastSeenTime': timeOfClient,
      'businessLastSeenTime': timeOfBusiness,
    });
  }

  return (chatRef, chatDoc, !chatDoc.exists);
}

/// Actualiza el tiempo de última vista de un chat; el chat debe existir, es
/// decir, debe haberse llamado a ensureSupportChatExists
Future<void> updateLastSeenTimeInSupportChat({
  required String orderId,
  required bool isBusiness,
}) async {
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(orderId);
  Map<Object, Object> object;
  if (isBusiness) {
    object = {'businessLastSeenTime': FieldValue.serverTimestamp()};
  } else {
    object = {'clientLastSeenTime': FieldValue.serverTimestamp()};
  }

  await chatRef.update(object);

  print("Hello world!");
}

Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesInSupportChat({
  required String orderId,
}) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(orderId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots();
}
