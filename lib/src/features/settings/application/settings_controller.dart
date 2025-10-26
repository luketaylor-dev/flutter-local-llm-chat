import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_interface/src/features/settings/data/settings_repository.dart';
import 'package:llm_interface/src/features/settings/domain/app_settings.dart';

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  late final SettingsRepository repository;

  @override
  AppSettings build() {
    repository = SettingsRepository();
    // load async
    _load();
    return AppSettings.defaults();
  }

  Future<void> _load() async {
    final AppSettings loaded = await repository.load();
    state = loaded;
  }

  Future<void> update(AppSettings newState) async {
    state = newState;
    await repository.save(newState);
  }
}
