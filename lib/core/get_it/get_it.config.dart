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
import '../../features/home/repository/progress_repository.dart' as _i585;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.singleton<_i585.ProgressRepository>(
      () => _i585.ProgressRepository(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i678.LocationBloc>(
      () => _i678.LocationBloc(gh<_i585.ProgressRepository>()),
    );
    return this;
  }
}
