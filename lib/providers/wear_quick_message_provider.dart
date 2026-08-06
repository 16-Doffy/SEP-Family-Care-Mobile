import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WearQuickMessageProvider extends ChangeNotifier {
  WearQuickMessageProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const int maxMessages = 5;
  static const _storageKey = 'wear_quick_messages_v1';
  static const defaultMessages = <String>[
    'Đang về nhà',
    'Đã đến nơi',
    'Đang chạy xe',
    'Đang bận',
    'Về trễ một chút',
  ];

  final FlutterSecureStorage _storage;

  List<String> _messages = List.of(defaultMessages);
  bool _loaded = false;
  bool _saving = false;

  List<String> get messages => List.unmodifiable(_messages);
  bool get loaded => _loaded;
  bool get saving => _saving;
  bool get canAdd => _messages.length < maxMessages;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _storageKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is List) {
        final saved = _sanitize(decoded.map((e) => e.toString()));
        if (saved.isNotEmpty) _messages = saved;
      }
    } catch (_) {
      _messages = List.of(defaultMessages);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(String text) async {
    final value = _clean(text);
    if (value == null || !canAdd) return;
    _messages = [..._messages, value];
    await _persist();
  }

  Future<void> updateAt(int index, String text) async {
    if (index < 0 || index >= _messages.length) return;
    final value = _clean(text);
    if (value == null) return;
    final next = [..._messages];
    next[index] = value;
    _messages = _sanitize(next);
    await _persist();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final next = [..._messages]..removeAt(index);
    _messages = next.isEmpty ? List.of(defaultMessages) : next;
    await _persist();
  }

  Future<void> reset() async {
    _messages = List.of(defaultMessages);
    await _persist();
  }

  String? _clean(String text) {
    final value = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return null;
    return value.length <= 40 ? value : value.substring(0, 40).trim();
  }

  List<String> _sanitize(Iterable<String> values) {
    final out = <String>[];
    for (final raw in values) {
      final value = _clean(raw);
      if (value == null || out.contains(value)) continue;
      out.add(value);
      if (out.length >= maxMessages) break;
    }
    return out;
  }

  Future<void> _persist() async {
    _saving = true;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(_messages));
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
