import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../repositories/i_progress_repository.dart';

@injectable
class SaveProgressUseCase {
  SaveProgressUseCase(this._repository);

  final IProgressRepository _repository;

  Future<void> call(List<LatLng> points) => _repository.save(points);
}