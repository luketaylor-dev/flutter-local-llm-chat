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

  factory AppSettings.defaults() => const AppSettings(
    serverUrl: 'http://127.0.0.1:8008',
    model: null,
    temperature: 0.7,
    maxTokens: 1014,
    maxHistoryMessages: 30,
    maxHistoryChars: 0,
    keepHeadCount: 3,
    enableStreaming: false,
    enableSummarization: false,
  );

  AppSettings copyWith({
    String? serverUrl,
    String? model = _sentinelString,
    double? temperature,
    int? maxTokens,
    int? maxHistoryMessages,
    int? maxHistoryChars,
    int? keepHeadCount,
    bool? enableStreaming,
    bool? enableSummarization,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      model: model != _sentinelString ? model : this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      maxHistoryMessages: maxHistoryMessages ?? this.maxHistoryMessages,
      maxHistoryChars: maxHistoryChars ?? this.maxHistoryChars,
      keepHeadCount: keepHeadCount ?? this.keepHeadCount,
      enableStreaming: enableStreaming ?? this.enableStreaming,
      enableSummarization: enableSummarization ?? this.enableSummarization,
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
    };
  }

  static AppSettings fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serverUrl: (map['serverUrl'] as String?) ?? 'http://127.0.0.1:8008',
      model: map['model'] as String?,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 512,
      maxHistoryMessages: (map['maxHistoryMessages'] as num?)?.toInt() ?? 30,
      maxHistoryChars: (map['maxHistoryChars'] as num?)?.toInt() ?? 12000,
      keepHeadCount: (map['keepHeadCount'] as num?)?.toInt() ?? 3,
      enableStreaming: (map['enableStreaming'] as bool?) ?? false,
      enableSummarization: (map['enableSummarization'] as bool?) ?? false,
    );
  }
}

const String _sentinelString = '__SENTINEL__';
