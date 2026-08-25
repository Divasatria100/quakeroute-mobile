import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/models/hazard.dart' show LatLng;
import '../../../../core/models/hazard_suggestion.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/state/app_providers.dart';

enum PhotoStep { pick, preview, uploading, review, submitting, success }

class PhotoReportState {
  const PhotoReportState({this.step = PhotoStep.pick, this.photoPath, this.suggestion, this.error, this.confirmedHazardId});
  final PhotoStep step;
  final String? photoPath;
  final HazardSuggestion? suggestion;
  final String? error;
  final String? confirmedHazardId;
  PhotoReportState copyWith({PhotoStep? step, String? Function()? photoPath, HazardSuggestion? Function()? suggestion, String? Function()? error, String? Function()? confirmedHazardId}) =>
      PhotoReportState(step: step ?? this.step, photoPath: photoPath == null ? this.photoPath : photoPath(), suggestion: suggestion == null ? this.suggestion : suggestion(), error: error == null ? this.error : error(), confirmedHazardId: confirmedHazardId == null ? this.confirmedHazardId : confirmedHazardId());
}

class PhotoReportController extends StateNotifier<PhotoReportState> {
  PhotoReportController(this._ref) : super(const PhotoReportState());
  final Ref _ref;
  final LocationService _location = const LocationService();

  void setPhoto(String path) => state = state.copyWith(step: PhotoStep.preview, photoPath: () => path, error: () => null);
  void clearPhoto() => state = const PhotoReportState();

  Future<void> upload() async {
    final path = state.photoPath;
    if (path == null) return;
    state = state.copyWith(step: PhotoStep.uploading, error: () => null);
    try {
      final loc = await _location.getCurrentLocationOrNull();
      if (loc == null) throw const ApiException(code: 'NO_LOCATION', message: 'Location unavailable. Enable location and try again.');
      final sug = await _ref.read(hazardReportRepositoryProvider).submitPhoto(photoPath: path, location: LatLng(loc.lat, loc.lng));
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.review, suggestion: () => sug);
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.preview, error: () => e.message.isNotEmpty ? e.message : 'Could not analyze photo.');
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.preview, error: () => 'Could not upload photo. Check your connection.');
    }
  }

  Future<void> confirm({Map<String, String>? edits}) async {
    final sug = state.suggestion;
    if (sug == null) return;
    state = state.copyWith(step: PhotoStep.submitting, error: () => null);
    try {
      final hazard = await _ref.read(hazardReportRepositoryProvider).confirmSuggestion(sug.suggestionId, edits: edits);
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.success, confirmedHazardId: () => hazard.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.review, error: () => e.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.review, error: () => 'Could not confirm. Please try again.');
    }
  }

  Future<void> reject() async {
    final sug = state.suggestion;
    if (sug == null) return;
    state = state.copyWith(step: PhotoStep.submitting, error: () => null);
    try {
      await _ref.read(hazardReportRepositoryProvider).rejectSuggestion(sug.suggestionId);
      if (!mounted) return;
      state = const PhotoReportState(); // back to pick
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.review, error: () => e.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(step: PhotoStep.review, error: () => 'Could not reject. Please try again.');
    }
  }
}

final photoReportControllerProvider = StateNotifierProvider<PhotoReportController, PhotoReportState>((ref) => PhotoReportController(ref));
