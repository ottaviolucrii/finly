import 'package:finly/features/ai/data/ai_remote_data_source.dart';
import 'package:finly/features/ai/data/ai_repository_impl.dart';
import 'package:finly/features/ai/domain/repositories/ai_repository.dart';
import 'package:get_it/get_it.dart';

/// Registers the AI quick add.
void registerAiModule(GetIt sl) {
  sl
    ..registerLazySingleton<AiRemoteDataSource>(() => AiRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<AiRepository>(() => AiRepositoryImpl(sl()));
}
