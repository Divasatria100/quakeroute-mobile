import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/features/map/data/hazard_repository.dart';
import 'package:quakeroute_mobile/features/map/data/road_segment_repository.dart';
import 'package:quakeroute_mobile/features/map/controller/hazard_map_controller.dart';
import 'package:quakeroute_mobile/features/map/controller/road_segment_controller.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart';
import 'package:quakeroute_mobile/core/models/road_segment.dart';
import 'widget_test.dart' show hazardPollIntervalOverride;

class _FakeHazardRepoBbox implements HazardRepository {
  String? lastBbox;
  String? lastUpdatedSince;
  @override
  Future<List<Hazard>> getHazards({String? status, String? bbox, DateTime? updatedSince}) async {
    lastBbox = bbox;
    lastUpdatedSince = updatedSince?.toIso8601String();
    return [];
  }
  @override
  Future<Hazard> getHazard(String hazardId) async => throw UnimplementedError();
}

class _FakeRoadRepoBbox implements RoadSegmentRepository {
  String? lastBbox;
  @override
  Future<List<RoadSegment>> getRoadSegments({String? bbox}) async { lastBbox = bbox; return []; }
}

void main() {
  test('hazard setBbox triggers refresh with bbox', () async {
    final fake = _FakeHazardRepoBbox();
    final container = ProviderContainer(overrides: [hazardRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()]);
    final ctrl = container.read(hazardMapControllerProvider.notifier);
    await ctrl.setBbox('106.8,-6.21,106.82,-6.2');
    expect(fake.lastBbox, '106.8,-6.21,106.82,-6.2');
    // duplicate bbox no second call
    fake.lastBbox = null;
    await ctrl.setBbox('106.8,-6.21,106.82,-6.2');
    expect(fake.lastBbox, isNull);
    addTearDown(container.dispose);
  });

  test('hazard pollDelta sends bbox + updated_since together', () async {
    final fake = _FakeHazardRepoBbox();
    final container = ProviderContainer(overrides: [hazardRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()]);
    final ctrl = container.read(hazardMapControllerProvider.notifier);
    await ctrl.setBbox('1,2,3,4');
    fake.lastBbox = null; fake.lastUpdatedSince = null;
    // need lastUpdated set via initial load
    await ctrl.load();
    fake.lastBbox = null; fake.lastUpdatedSince = null;
    await ctrl.pollDelta();
    expect(fake.lastBbox, '1,2,3,4');
    expect(fake.lastUpdatedSince, isNotNull);
    addTearDown(container.dispose);
  });

  test('road segment setBbox', () async {
    final fake = _FakeRoadRepoBbox();
    final container = ProviderContainer(overrides: [roadSegmentRepositoryProvider.overrideWithValue(fake)]);
    final ctrl = container.read(roadSegmentControllerProvider.notifier);
    await ctrl.setBbox('10,20,30,40');
    expect(fake.lastBbox, '10,20,30,40');
    addTearDown(container.dispose);
  });

  test('null bbox keeps full fetch', () async {
    final fake = _FakeHazardRepoBbox();
    final container = ProviderContainer(overrides: [hazardRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()]);
    final ctrl = container.read(hazardMapControllerProvider.notifier);
    await ctrl.load();
    expect(fake.lastBbox, isNull);
    addTearDown(container.dispose);
  });
}
