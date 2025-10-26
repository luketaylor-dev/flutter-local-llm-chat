import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_interface/src/features/settings/application/settings_controller.dart';
import 'package:llm_interface/src/features/settings/domain/app_settings.dart';

class SettingsDrawer extends ConsumerStatefulWidget {
  const SettingsDrawer({super.key});

  @override
  ConsumerState<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends ConsumerState<SettingsDrawer> {
  late final TextEditingController _urlController;
  late final TextEditingController _modelController;
  double _temperature = 0.7;
  int _maxTokens = 512;
  int _maxHistoryMessages = 30;
  int _maxHistoryChars = 12000;
  int _keepHeadCount = 3;
  bool _enableStreaming = false;
  bool _enableSummarization = false;

  @override
  void initState() {
    super.initState();
    final AppSettings s = ref.read(settingsProvider);
    _urlController = TextEditingController(text: s.serverUrl);
    _modelController = TextEditingController(text: s.model ?? '');
    _temperature = s.temperature;
    _maxTokens = s.maxTokens;
    _maxHistoryMessages = s.maxHistoryMessages;
    _maxHistoryChars = s.maxHistoryChars;
    _keepHeadCount = s.keepHeadCount;
    _enableStreaming = s.enableStreaming;
    _enableSummarization = s.enableSummarization;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings current = ref.watch(settingsProvider);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            const ListTile(
              title: Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://127.0.0.1:8008',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model (optional)',
                hintText: 'e.g., llama-3.1-8b',
              ),
            ),
            const SizedBox(height: 8),
            _buildSlider(
              'Temperature',
              _temperature,
              0.0,
              1.5,
              (double v) => setState(() => _temperature = v),
            ),
            _buildStepper(
              'Max tokens',
              _maxTokens,
              32,
              8192,
              (int v) => setState(() => _maxTokens = v),
            ),
            _buildStepper(
              'Max history messages',
              _maxHistoryMessages,
              5,
              200,
              (int v) => setState(() => _maxHistoryMessages = v),
            ),
            _buildStepper(
              'Max history chars (0=disabled)',
              _maxHistoryChars,
              0,
              200000,
              (int v) => setState(() => _maxHistoryChars = v),
            ),
            _buildStepper(
              'Keep head messages',
              _keepHeadCount,
              0,
              20,
              (int v) => setState(() => _keepHeadCount = v),
            ),
            SwitchListTile(
              title: const Text('Enable streaming (experimental)'),
              value: _enableStreaming,
              onChanged: (bool v) => setState(() => _enableStreaming = v),
            ),
            SwitchListTile(
              title: const Text('Enable summarization memory (experimental)'),
              value: _enableSummarization,
              onChanged: (bool v) => setState(() => _enableSummarization = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final AppSettings next = current.copyWith(
                  serverUrl: _urlController.text.trim().isEmpty
                      ? current.serverUrl
                      : _urlController.text.trim(),
                  model: _modelController.text.trim().isEmpty
                      ? null
                      : _modelController.text.trim(),
                  temperature: _temperature,
                  maxTokens: _maxTokens,
                  maxHistoryMessages: _maxHistoryMessages,
                  maxHistoryChars: _maxHistoryChars,
                  keepHeadCount: _keepHeadCount,
                  enableStreaming: _enableStreaming,
                  enableSummarization: _enableSummarization,
                );
                await ref.read(settingsProvider.notifier).update(next);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildStepper(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: <Widget>[
        Expanded(child: Text('$label: $value')),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
