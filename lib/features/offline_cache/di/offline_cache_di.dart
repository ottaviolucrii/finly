import 'package:finly/core/offline/cache_store.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the settings of the copies kept for use without internet.
///
/// The [CacheStore] itself is registered by `main`, because the HTTP client of
/// Supabase needs it before anything else exists.
void registerOfflineCacheModule(GetIt sl) {
  sl.registerFactory(() => OfflineCacheCubit(sl<CacheStore>()));
}
