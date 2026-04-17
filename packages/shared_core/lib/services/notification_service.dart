import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref _ref;
  StreamSubscription? _subscription;

  NotificationService(this._ref);

  void init(BuildContext context) {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final supabase = Supabase.instance.client;

    _subscription?.cancel();
    _subscription = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((data) {
          if (data.isNotEmpty) {
            final notification = data.first;
            final createdAt = DateTime.parse(notification['created_at']);
            
            // Only show if it's new (within last 30 seconds)
            if (DateTime.now().difference(createdAt).inSeconds < 30) {
              _showNotification(context, notification);
            }
          }
        });
  }

  void _showNotification(BuildContext context, Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message, style: const TextStyle(fontSize: 12)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.greenAccent,
          onPressed: () {
             // Future: Navigate based on notification['type']
          },
        ),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
