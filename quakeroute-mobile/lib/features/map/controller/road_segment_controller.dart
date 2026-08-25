import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/road_segment.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/qr_tokens.dart';

class RoadSegmentState {
  const RoadSegmentState({this.segments = const [], this.loading = false});
  final List<RoadSegment> segments;
  final bool loading;
}

Color colorForCondition(String condition) => switch (condition) {
      'Critical' => QRTokens.semanticCritical,
      'Danger' => QRTokens.semanticDanger,
      'Warning' => QRTokens.semanticWarning,
      'Uncertain' => QRTokens.semanticUncertain,
      'Safe' => QRTokens.semanticSafe,
      'Info' => QRTokens.semanticInfo,
      _ => QRTokens.textDisabled,
    };

double strokeForCondition(String condition) => switch (condition) {
      'Critical' => 6,
      'Danger' => 5,
      'Warning' => 5,
      'Uncertain' => 4,
      _ => 3,
    };

bool isDashed(String condition) => condition == 'Uncertain';

class RoadSegmentController extends StateNotifier<RoadSegmentState> {
  RoadSegmentController(this._ref) : super(const RoadSegmentState());

  final Ref _ref;
  String? _bbox;

  Future<void> load() async {
    if (state.loading) return;
    state = const RoadSegmentState(loading: true);
    try {
      final repo = _ref.read(roadSegmentRepositoryProvider);
      final list = await repo.getRoadSegments(bbox: _bbox);
      if (!mounted) return;
      state = RoadSegmentState(segments: list);
    } catch (_) {
      if (!mounted) return;
      state = const RoadSegmentState();
    }
  }

  Future<void> setBbox(String? bbox) async {
    if (_bbox == bbox) return;
    _bbox = bbox;
    await load();
  }
}

final roadSegmentControllerProvider = StateNotifierProvider<RoadSegmentController, RoadSegmentState>((ref) {
  return RoadSegmentController(ref);
});
