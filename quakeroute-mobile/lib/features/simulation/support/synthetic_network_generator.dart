import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;

import '../../../core/models/hazard.dart' show LatLng;

/// Mirrors PHP SyntheticNetworkGenerator (quakeroute-api/app/Modules/Simulation/Support/SyntheticNetworkGenerator.php)
/// Minimal deterministic generation for preview routing before Run.
/// Structure: 4x4 grid (16 nodes), spacing ~ span/(cols-1), horizontal+vertical edges + 2-4 diagonals seeded.
class SyntheticNetworkGenerator {
  /// Generate deterministic synthetic network around center.
  /// Returns nodes, segments, destinations, nodeCoords map.
  static Map<String, dynamic> generate(double centerLat, double centerLng, int seed, int radiusM) {
    // Use Dart Random with seed for jitter/diagonals - close to PHP Mt19937 but minimal.
    // For exact backend match, jitter is small (±25m) so difference is negligible for preview.
    final rand = math.Random(seed);

    const cols = 4;
    const rows = 4;
    final span = radiusM * 1.2;
    final spacingX = span / (cols - 1);
    final spacingY = span / (rows - 1);

    final nodes = <Map<String, dynamic>>[];
    final nodeCoords = <String, List<double>>{}; // id -> [lat,lng]

    final labels = ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P'];

    String nid(int r, int c) => deterministicUuid(seed, 'node', r * cols + c, centerLat, centerLng);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        var offX = (c - (cols - 1) / 2) * spacingX;
        var offY = (r - (rows - 1) / 2) * spacingY;
        offX += rand.nextInt(51) - 25; // -25..25
        offY += rand.nextInt(51) - 25;
        final d = metersToDegrees(offY, offX, centerLat);
        final lat = centerLat + d[0];
        final lng = centerLng + d[1];
        final id = nid(r, c);
        nodes.add({'id': id, 'lat': lat, 'lng': lng, 'label': labels[idx]});
        nodeCoords[id] = [lat, lng];
      }
    }

    final segments = <Map<String, dynamic>>[];
    var segIdx = 0;

    void addSeg(String from, String to) {
      final id = deterministicUuid(seed, 'seg', segIdx++, centerLat, centerLng);
      final c1 = nodeCoords[from]!;
      final c2 = nodeCoords[to]!;
      final wkt = 'LINESTRING(${c1[1].toStringAsFixed(6)} ${c1[0].toStringAsFixed(6)}, ${c2[1].toStringAsFixed(6)} ${c2[0].toStringAsFixed(6)})';
      segments.add({'id': id, 'from': from, 'to': to, 'wkt': wkt, 'base_cost': 10.0, 'bidirectional': true, 'coords': [LatLng(c1[0], c1[1]), LatLng(c2[0], c2[1])]});
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols - 1; c++) {
        addSeg(nid(r, c), nid(r, c+1));
      }
    }
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows - 1; r++) {
        addSeg(nid(r, c), nid(r+1, c));
      }
    }
    final extra = 2 + rand.nextInt(3); // 2..4
    for (var i = 0; i < extra; i++) {
      final r = rand.nextInt(rows - 1);
      final c = rand.nextInt(cols - 1);
      if (rand.nextBool()) {
        addSeg(nid(r, c), nid(r+1, c+1));
      } else {
        addSeg(nid(r, c+1), nid(r+1, c));
      }
    }

    final destOffsets = [
      {'name': 'Shelter North-West', 'type': 'Shelter', 'dx': -radiusM * 0.7, 'dy': radiusM * 0.7},
      {'name': 'Shelter South-East', 'type': 'Shelter', 'dx': radiusM * 0.7, 'dy': -radiusM * 0.7},
      {'name': 'Medical North-East', 'type': 'MedicalFacility', 'dx': radiusM * 0.6, 'dy': radiusM * 0.6},
      {'name': 'Medical South-West', 'type': 'MedicalFacility', 'dx': -radiusM * 0.6, 'dy': -radiusM * 0.6},
      {'name': 'Shelter Central East', 'type': 'Shelter', 'dx': radiusM * 0.5, 'dy': 0.0},
    ];
    final destinations = <Map<String, dynamic>>[];
    for (var idx = 0; idx < destOffsets.length; idx++) {
      final off = destOffsets[idx];
      final d = metersToDegrees((off['dy'] as double), (off['dx'] as double), centerLat);
      final lat = centerLat + d[0];
      final lng = centerLng + d[1];
      final id = deterministicUuid(seed, 'dest', idx, centerLat, centerLng);
      destinations.add({'id': id, 'name': off['name'], 'type': off['type'], 'lat': lat, 'lng': lng});
    }

    return {'nodes': nodes, 'segments': segments, 'destinations': destinations, 'nodeCoords': nodeCoords};
  }

  static List<double> metersToDegrees(double dy, double dx, double centerLat) {
    final dLat = dy / 111000.0;
    var cosVal = math.cos(centerLat * math.pi / 180.0);
    if (cosVal.abs() < 0.01) cosVal = 0.01;
    final dLng = dx / (111000.0 * cosVal);
    return [dLat, dLng];
  }

  static String deterministicUuid(int seed, String prefix, int idx, double centerLat, double centerLng) {
    // Match PHP: round(center,5) then string cast without trailing zeros (e.g. -6.2 not -6.20000)
    final rLat = (centerLat * 1e5).round() / 1e5;
    final rLng = (centerLng * 1e5).round() / 1e5;
    final latStr = rLat.toString();
    final lngStr = rLng.toString();
    final key = '$seed-$prefix-$idx-$latStr-$lngStr';
    final hash = crypto.md5.convert(utf8.encode(key)).toString();
    return '${hash.substring(0,8)}-${hash.substring(8,12)}-${hash.substring(12,16)}-${hash.substring(16,20)}-${hash.substring(20,32)}';
  }

  /// Find nearest node id to a lat/lng.
  static String findNearestNode(double lat, double lng, List<Map<String, dynamic>> nodes) {
    var best = nodes[0]['id'] as String;
    var bestDist = double.infinity;
    for (final n in nodes) {
      final dLat = (n['lat'] as double) - lat;
      final dLng = (n['lng'] as double) - lng;
      final dist = dLat*dLat + dLng*dLng;
      if (dist < bestDist) {
        bestDist = dist;
        best = n['id'] as String;
      }
    }
    return best;
  }

  /// Dijkstra over cached network.
  static List<LatLng> shortestPathWithCache(
    List<Map<String, dynamic>> nodes,
    List<Map<String, dynamic>> segments,
    LatLng origin,
    LatLng dest,
  ) {
    if (nodes.isEmpty) return [origin, dest];
    final originNode = findNearestNode(origin.lat, origin.lng, nodes);
    final destNode = findNearestNode(dest.lat, dest.lng, nodes);

    final adj = <String, List<Map<String, dynamic>>>{};
    for (final n in nodes) {
      adj[n['id'] as String] = [];
    }
    for (final s in segments) {
      final from = s['from'] as String;
      final to = s['to'] as String;
      final cost = (s['base_cost'] as num).toDouble();
      adj[from]!.add({'to': to, 'cost': cost});
      if (s['bidirectional'] as bool) {
        adj[to]!.add({'to': from, 'cost': cost});
      }
    }

    final dist = <String, double>{};
    final prev = <String, String?>{};
    final visited = <String>{};
    for (final n in nodes) {
      dist[n['id'] as String] = double.infinity;
      prev[n['id'] as String] = null;
    }
    dist[originNode] = 0;
    final queue = <String>[originNode];

    while (queue.isNotEmpty) {
      String u = queue.reduce((a, b) => dist[a]! < dist[b]! ? a : b);
      queue.remove(u);
      if (visited.contains(u)) continue;
      visited.add(u);
      if (u == destNode) break;
      for (final edge in adj[u]!) {
        final v = edge['to'] as String;
        if (visited.contains(v)) continue;
        final alt = dist[u]! + (edge['cost'] as double);
        if (alt < dist[v]!) {
          dist[v] = alt;
          prev[v] = u;
          if (!queue.contains(v)) queue.add(v);
        }
      }
    }

    if (dist[destNode] == double.infinity) {
      return [origin, dest];
    }

    // Reconstruct node path origin -> dest
    final path = <String>[];
    String? cur = destNode;
    while (cur != null) {
      path.add(cur);
      if (cur == originNode) break;
      cur = prev[cur];
    }
    final ordered = path.reversed.toList();

    final coords = <LatLng>[origin];
    for (final nid in ordered) {
      final nodeData = nodes.firstWhere((n) => n['id'] == nid);
      coords.add(LatLng(nodeData['lat'] as double, nodeData['lng'] as double));
    }
    coords.add(dest);

    // Deduplicate
    final dedup = <LatLng>[];
    for (final p in coords) {
      if (dedup.isEmpty || dedup.last.lat != p.lat || dedup.last.lng != p.lng) {
        dedup.add(p);
      }
    }
    return dedup;
  }

  /// Convenience: generate network then route.
  static List<LatLng> shortestPath(double centerLat, double centerLng, int seed, int radiusM, LatLng origin, LatLng dest) {
    final gen = generate(centerLat, centerLng, seed, radiusM);
    final nodes = gen['nodes'] as List<Map<String, dynamic>>;
    final segments = gen['segments'] as List<Map<String, dynamic>>;
    return shortestPathWithCache(nodes, segments, origin, dest);
  }
}
