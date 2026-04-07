import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String notes;
  final String? businessId;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.notes,
    this.businessId,
  });

  factory OrderItem.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return OrderItem(
        productId: '',
        name: '',
        price: 0.0,
        quantity: 1,
        notes: '',
        businessId: null,
      );
    }

    return OrderItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity:
          (map['quantity'] as int?) ?? (map['quantity'] as num?)?.toInt() ?? 1,
      notes: map['notes'] as String? ?? '',
      businessId: map['businessId'] as String?,
    );
  }

  @override
  String toString() {
    return 'OrderItem(productId: $productId, name: $name, price: $price, quantity: $quantity, notes: $notes, businessId: $businessId)';
  }
}

class OrderDetail {
  final String orderId;
  final String businessId;
  final String userId;
  final String userDisplayName;
  final String userNumeroDeControl;
  final String status;
  final double totalPrice;
  final String paymentMethod;
  final DateTime? createdAt;
  final DateTime? scheduledPickupTime;
  final List<OrderItem> items;
  final bool hasNewMessages;
  final bool isBusiness;
  final String? redeemCode;

  OrderDetail({
    required this.orderId,
    required this.businessId,
    required this.userId,
    required this.userDisplayName,
    required this.userNumeroDeControl,
    required this.status,
    required this.totalPrice,
    required this.paymentMethod,
    required this.createdAt,
    required this.scheduledPickupTime,
    required this.items,
    required this.hasNewMessages,
    required this.isBusiness,
    this.redeemCode,
  });

  factory OrderDetail.fromMap(
    String orderId,
    Map<String, dynamic> map, {
    bool hasNewMessages = false,
    bool isBusiness = false,
  }) {
    final rawItems = map['items'] as List<dynamic>?;

    return OrderDetail(
      orderId: orderId,
      businessId: map['businessId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userDisplayName: map['userDisplayName'] as String? ?? '',
      userNumeroDeControl: map['userNumeroDeControl'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'unknown',
      createdAt: _parseDateTime(map['createdAt']),
      scheduledPickupTime: _parseDateTime(map['scheduledPickupTime']),
      items:
          rawItems
              ?.whereType<Map<String, dynamic>>()
              .map(OrderItem.fromMap)
              .toList() ??
          [],
      hasNewMessages: hasNewMessages,
      isBusiness: isBusiness,
      redeemCode: map['redeemCode'] as String?,
    );
  }

  @override
  String toString() {
    return 'OrderDetail(orderId: $orderId, businessId: $businessId, userId: $userId, userDisplayName: $userDisplayName, userNumeroDeControl: $userNumeroDeControl, status: $status, totalPrice: $totalPrice, paymentMethod: $paymentMethod, createdAt: $createdAt, scheduledPickupTime: $scheduledPickupTime, items: $items, hasNewMessages: $hasNewMessages, isBusiness: $isBusiness, redeemCode: $redeemCode)';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
