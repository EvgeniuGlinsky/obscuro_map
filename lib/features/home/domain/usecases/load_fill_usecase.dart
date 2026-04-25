import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../repositories/i_progress_repository.dart';

@injectable
class LoadFillUseCase {
  LoadFillUseCase(this._repository);

  final IProgressRepository _repository;

  List<LatLng> call() => _repository.loadFill();
}
