import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/qr_tokens.dart';

/// Wraps flutter_map + overlay layers — §4.3 organism.
/// Hazard/destination overlays are passed in by feature screens.
class QRMapCanvas extends StatelessWidget {
  const QRMapCanvas({
    super.key,
    this.center,
    this.markers = const [],
    this.polylines = const [],
    this.mapController,
    this.onPositionChanged,
  });

  final LatLng? center;
  final List<Marker> markers;
  final List<Polyline<Object>> polylines;

  /// Optional externally-owned controller so screens can move the camera
  /// (e.g. center on the user position, FR-001).
  final MapController? mapController;
  final void Function(MapCamera, bool)? onPositionChanged;

  static const _defaultCenter = LatLng(-6.20, 106.81);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center ?? _defaultCenter,
        initialZoom: 13,
        onPositionChanged: onPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.quakeroute.mobile',
        ),
        if (polylines.isNotEmpty) PolylineLayer<Object>(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        // HUD crosshair for user location placeholder
        const _HudCrosshair(),
      ],
    );
  }
}

class _HudCrosshair extends StatelessWidget {
  const _HudCrosshair();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: QRTokens.accentCyan, width: 1.5),
            borderRadius: BorderRadius.circular(QRTokens.radiusFull),
          ),
          child: const Icon(
            Icons.my_location,
            size: QRTokens.iconSm,
            color: QRTokens.accentCyan,
          ),
        ),
      ),
    );
  }
}
