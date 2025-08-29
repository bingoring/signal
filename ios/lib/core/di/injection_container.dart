import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../features/buddy/data/services/buddy_api_service.dart';
import '../../features/buddy/presentation/cubit/buddy_cubit.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // Network client
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio();
    // TODO: Add interceptors, base URL, etc.
    return dio;
  });

  // Buddy API Service
  sl.registerLazySingleton<BuddyApiService>(() => BuddyApiService(sl()));

  // Buddy Cubit
  sl.registerFactory<BuddyCubit>(() => BuddyCubit(sl()));
}