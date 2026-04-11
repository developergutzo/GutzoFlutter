import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void set(bool value) => state = value;
}

final globalLoadingProvider = NotifierProvider<LoadingNotifier, bool>(LoadingNotifier.new);
