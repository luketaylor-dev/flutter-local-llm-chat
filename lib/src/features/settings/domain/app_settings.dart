class AppSettings {
  const AppSettings({
    required this.serverUrl,
    this.model,
    required this.temperature,
    required this.maxTokens,
    required this.maxHistoryMessages,
    required this.maxHistoryChars,
    required this.keepHeadCount,
    required this.enableStreaming,
    required this.enableSummarization,
    required this.enableDndMode,
    required this.dndRules,
    required this.showDndBanner,
    required this.showSummaryBanner,
  });

  final String serverUrl;
  final String? model;
  final double temperature;
  final int maxTokens;
  final int maxHistoryMessages;
  final int maxHistoryChars;
  final int keepHeadCount;
  final bool enableStreaming;
  final bool enableSummarization;
  final bool enableDndMode;
  final String dndRules;
  final bool showDndBanner;
  final bool showSummaryBanner;

  factory AppSettings.defaults() {
    return const AppSettings(
      serverUrl: 'http://127.0.0.1:8008',
      model: null,
      temperature: 0.7,
      maxTokens: 2048,
      maxHistoryMessages: 30,
      maxHistoryChars: 0,
      keepHeadCount: 3,
      enableStreaming: false,
      enableSummarization: false,
      enableDndMode: false,
      dndRules: _defaultDndRules,
      showDndBanner: false,
      showSummaryBanner: false,
    );
  }

  AppSettings copyWith({
    String? serverUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    int? maxHistoryMessages,
    int? maxHistoryChars,
    int? keepHeadCount,
    bool? enableStreaming,
    bool? enableSummarization,
    bool? enableDndMode,
    String? dndRules,
    bool? showDndBanner,
    bool? showSummaryBanner,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      maxHistoryMessages: maxHistoryMessages ?? this.maxHistoryMessages,
      maxHistoryChars: maxHistoryChars ?? this.maxHistoryChars,
      keepHeadCount: keepHeadCount ?? this.keepHeadCount,
      enableStreaming: enableStreaming ?? this.enableStreaming,
      enableSummarization: enableSummarization ?? this.enableSummarization,
      enableDndMode: enableDndMode ?? this.enableDndMode,
      dndRules: dndRules ?? this.dndRules,
      showDndBanner: showDndBanner ?? this.showDndBanner,
      showSummaryBanner: showSummaryBanner ?? this.showSummaryBanner,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'serverUrl': serverUrl,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'maxHistoryMessages': maxHistoryMessages,
      'maxHistoryChars': maxHistoryChars,
      'keepHeadCount': keepHeadCount,
      'enableStreaming': enableStreaming,
      'enableSummarization': enableSummarization,
      'enableDndMode': enableDndMode,
      'dndRules': dndRules,
      'showDndBanner': showDndBanner,
      'showSummaryBanner': showSummaryBanner,
    };
  }

  static AppSettings fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serverUrl: (map['serverUrl'] as String?) ?? 'http://127.0.0.1:8008',
      model: map['model'] as String?,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 2048,
      maxHistoryMessages: (map['maxHistoryMessages'] as num?)?.toInt() ?? 30,
      maxHistoryChars: (map['maxHistoryChars'] as num?)?.toInt() ?? 12000,
      keepHeadCount: (map['keepHeadCount'] as num?)?.toInt() ?? 3,
      enableStreaming: (map['enableStreaming'] as bool?) ?? false,
      enableSummarization: (map['enableSummarization'] as bool?) ?? false,
      enableDndMode: (map['enableDndMode'] as bool?) ?? false,
      dndRules: (map['dndRules'] as String?) ?? _defaultDndRules,
      showDndBanner: (map['showDndBanner'] as bool?) ?? false,
      showSummaryBanner: (map['showSummaryBanner'] as bool?) ?? false,
    );
  }
}

const String _defaultDndRules =
    'You are a Dungeon Master facilitating DnD-style roleplay.\n'
    'Each user message may include a line like [dice roll = X].\n'
    'Interpret X as a d20 roll: low=failure, high=success, 1=critical fail, 20=critical success.\n'
    'Use only the player\'s [dice roll = X]; never roll yourself.\n'
    'Determine outcome by task difficulty and the character\'s traits/skills/conditions/equipment.\n'
    'Only 1 is [critical failure] and only 20 is [critical success]; do not treat other values as critical.\n'
    'Be conservative with successes: low rolls should usually fail unless the task is trivial or strongly favored; high rolls should usually succeed unless the task is very hard.\n'
    'At the very top of your reply, include exactly one outcome tag based on X and difficulty: [critical success], [succeeded], [failed], or [critical failure].\n'
    'Keep narrative consistent with established facts; if an action is impossible, explain constraints and offer alternatives.\n'
    'I control my character\'s actions and dialogue. You handle NPCs and the world. Do not act for my character—wait for my input first.\n'
    'Avoid repeating the same phrases; vary wording and advance the scene each turn.\n'
    'Any other bracketed text I send (e.g., [pause], [retcon …], [scene cut]) is a Dungeon Master command, not character speech; follow it without die rolls.\n'
    'If no [dice roll = X] is present for an action that needs one, ask once for a roll before resolving.';
