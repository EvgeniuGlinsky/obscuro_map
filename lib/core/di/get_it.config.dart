// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../features/home/bloc/location_bloc.dart' as _i678;
import '../../features/home/data/progress_repository.dart' as _i977;
import '../../features/home/domain/repositories/i_progress_repository.dart'
    as _i1021;
import '../../features/home/domain/usecases/append_track_point_usecase.dart'
    as _i245;
import '../../features/home/domain/usecases/compute_fill_area_usecase.dart'
    as _i408;
import '../../features/home/domain/usecases/erase_points_usecase.dart' as _i752;
import 'app_module.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    await gh.singletonAsync<_i460.SharedPreferences>(
      () => appModule.sharedPreferences,
      preResolve: true,
    );
    gh.lazySingleton<_i245.AppendTrackPointUseCase>(
      () => const _i245.AppendTrackPointUseCase(),
    );
    gh.lazySingleton<_i408.ComputeFillAreaUseCase>(
      () => const _i408.ComputeFillAreaUseCase(),
    );
    gh.lazySingleton<_i752.ErasePointsUseCase>(
      () => const _i752.ErasePointsUseCase(),
    );
    gh.singleton<_i1021.IProgressRepository>(
      () => _i977.ProgressRepository(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i678.LocationBloc>(
      () => _i678.LocationBloc(
        gh<_i1021.IProgressRepository>(),
        gh<_i245.AppendTrackPointUseCase>(),
        gh<_i752.ErasePointsUseCase>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i460.AppModule {}
