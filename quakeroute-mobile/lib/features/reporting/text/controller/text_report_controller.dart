import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/models/hazard.dart' show LatLng;
import '../../../../core/models/hazard.dart' as h;
import '../../../../core/network/api_exception.dart';
import '../../../../core/state/app_providers.dart';

class TextReportState {
  const TextReportState({this.submitting = false, this.error, this.success = false, this.hazards = const []});
  final bool submitting;
  final String? error;
  final bool success;
  final List<h.Hazard> hazards;
  TextReportState copyWith({bool? submitting, String? Function()? error, bool? success, List<h.Hazard>? hazards}) =>
      TextReportState(submitting: submitting ?? this.submitting, error: error == null ? this.error : error(), success: success ?? this.success, hazards: hazards ?? this.hazards);
}

class TextReportController extends StateNotifier<TextReportState> {
  TextReportController(this._ref) : super(const TextReportState());
  final Ref _ref;
  final LocationService _location = const LocationService();

  Future<void> submit(String text) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(error: () => 'Description cannot be empty.');
      return;
    }
    state = state.copyWith(submitting: true, error: () => null);
    try {
      final loc = await _location.getCurrentLocationOrNull();
      if (loc == null) throw const ApiException(code: 'NO_LOCATION', message: 'Location unavailable. Enable location and try again.');
      final hazards = await _ref.read(hazardReportRepositoryProvider).submitText(text: text.trim(), location: LatLng(loc.lat, loc.lng));
      if (!mounted) return;
      state = TextReportState(success: true, hazards: hazards);
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(submitting: false, error: () => e.message.isNotEmpty ? e.message : 'Could not submit text report.');
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(submitting: false, error: () => 'Could not submit text report. Check your connection.');
    }
  }

  void reset() => state = const TextReportState();
}

final textReportControllerProvider = StateNotifierProvider<TextReportController, TextReportState>((ref) => TextReportController(ref));
