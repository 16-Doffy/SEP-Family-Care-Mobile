class FeatureAccess {
  final Map<String, dynamic> raw;

  const FeatureAccess(this.raw);

  factory FeatureAccess.fromJson(dynamic json) {
    if (json is Map) {
      return FeatureAccess(Map<String, dynamic>.from(json));
    }
    return const FeatureAccess({});
  }

  bool get calendarEnabled =>
      flag('calendar.enabled', aliases: const ['calendarEnabled']);

  bool get calendarReminders =>
      flag('calendar.reminders', aliases: const ['calendarReminders']);

  bool get calendarRecurringEvents => flag(
    'calendar.recurringEvents',
    aliases: const ['calendarRecurringEvents'],
  );

  bool get aiEnabled => flag('ai.enabled', aliases: const ['aiEnabled']);
  bool get advancedFinance =>
      flag('finance.advanced', aliases: const ['advancedFinance']);
  bool get advancedReports =>
      flag('reports.advanced', aliases: const ['advancedReports']);
  bool get aiChatbot => flag('ai.chatbot', aliases: const ['aiChatbot']);
  bool get sos => flag('sos.enabled', aliases: const ['sos']);
  bool get unlimitedStorage =>
      flag('storage.unlimited', aliases: const ['unlimitedStorage']);

  dynamic get maxFamilies =>
      value('families.max', aliases: const ['maxFamilies']);

  bool flag(String path, {List<String> aliases = const []}) {
    final v = value(path, aliases: aliases);
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'enabled';
  }

  dynamic value(String path, {List<String> aliases = const []}) {
    final candidates = [path, ...aliases];
    for (final key in candidates) {
      if (raw.containsKey(key)) return raw[key];
      final nested = _nestedValue(key);
      if (nested != null) return nested;
    }
    return null;
  }

  dynamic _nestedValue(String path) {
    dynamic current = raw;
    for (final part in path.split('.')) {
      if (current is! Map || !current.containsKey(part)) return null;
      current = current[part];
    }
    return current;
  }
}
