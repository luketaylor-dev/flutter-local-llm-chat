import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:llm_interface/src/features/chat/data/llm_api_service.dart';
import 'package:llm_interface/src/features/chat/data/llm_repository.dart';
import 'package:llm_interface/src/features/settings/domain/app_settings.dart';

final GetIt getIt = GetIt.instance;

void configureDependencies() {
  if (getIt.isRegistered<Dio>()) {
    return;
  }
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  getIt.registerSingleton<Dio>(dio);
  final AppSettings initial = AppSettings.defaults();
  final LlmApiService apiService = LlmApiService(
    dio: getIt.get<Dio>(),
    baseUrl: initial.serverUrl,
    model: initial.model,
  );
  getIt.registerSingleton<LlmApiService>(apiService);
  final LlmRepository repository = LlmRepository(
    apiService: getIt.get<LlmApiService>(),
  );
  getIt.registerSingleton<LlmRepository>(repository);
}
