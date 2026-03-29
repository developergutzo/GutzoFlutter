import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for local search history management
final searchServiceProvider = NotifierProvider<SearchNotifier, List<String>>(() {
  return SearchNotifier();
});

class SearchNotifier extends Notifier<List<String>> {
  static const String _historyKey = 'recent_searches';
  static const int _maxHistory = 8;
  
  late SharedPreferences _prefs;

  @override
  List<String> build() {
    _initPrefs();
    return [];
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final history = _prefs.getStringList(_historyKey);
    if (history != null) {
      state = history;
    }
  }

  /// Adds a new query to the top of the history list, maintaining the limit of 8
  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final currentHistory = List<String>.from(state);
    
    // Remove if already exists to move it to top
    currentHistory.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
    
    // Add to top
    currentHistory.insert(0, query.trim());
    
    // Limit to 8
    if (currentHistory.length > _maxHistory) {
      currentHistory.removeRange(_maxHistory, currentHistory.length);
    }
    
    state = currentHistory;
    await _prefs.setStringList(_historyKey, currentHistory);
  }

  /// Clears the search history from local storage
  Future<void> clearHistory() async {
    state = [];
    await _prefs.remove(_historyKey);
  }
}
