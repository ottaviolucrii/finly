import 'package:finly/features/summary/data/summary_notifier.dart';
import 'package:get_it/get_it.dart';

/// Registers the monthly summary notification.
void registerSummaryModule(GetIt sl) {
  sl.registerLazySingleton<SummaryNotifier>(LocalSummaryNotifier.new);
}
