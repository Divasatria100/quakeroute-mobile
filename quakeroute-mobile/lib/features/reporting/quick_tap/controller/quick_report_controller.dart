import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/hazard.dart' show LatLng;
import '../../../../core/network/api_exception.dart';
import '../../../../core/state/app_providers.dart';


class QuickReportState {
  const QuickReportState({this.submittingType, this.error, this.successId});
  final HazardType? submittingType;
  final String? error;
  final String? successId;
  bool get isSubmitting => submittingType != null;
  QuickReportState copyWith({HazardType? Function()? submittingType, String? Function()? error, String? Function()? successId}) =>
      QuickReportState(submittingType: submittingType == null ? this.submittingType : submittingType(), error: error == null ? this.error : error(), successId: successId == null ? this.successId : successId());
}

class QuickReportController extends StateNotifier<QuickReportState> {
  QuickReportController(this._ref) : super(const QuickReportState());
  final Ref _ref;
  final LocationService _location = const LocationService();

  Future<void> submit(HazardType type) async {
    state = QuickReportState(submittingType: type);
    try {
      var loc = await _location.getCurrentLocationOrNull();
      if (loc == null) {
        throw const ApiException(code: 'NO_LOCATION', message: 'Location unavailable. Enable location and try again.');
      }
      final repo = _ref.read(hazardReportRepositoryProvider);
      final hazard = await repo.submitQuick(type: type, location: LatLng(loc.lat, loc.lng));
      if (!mounted) return;
      state = QuickReportState(successId: hazard.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      state = QuickReportState(error: e.message.isNotEmpty ? e.message : 'Could not submit quick report. Please try again.');
    } catch (_) {
      if (!mounted) return;
      state = QuickReportState(error: 'Could not submit quick report. Check your connection.');
    }
  }

  void clear() => state = const QuickReportState();
}

final quickReportControllerProvider = StateNotifierProvider<QuickReportController, QuickReportState>((ref) => QuickReportController(ref));
