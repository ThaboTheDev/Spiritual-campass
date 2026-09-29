import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/coordinates.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/centre.dart';
import '../../../services/navigation_launcher.dart';
import '../../location/location_controller.dart';
import '../centres_providers.dart';
import 'centre_bottom_sheet.dart';

/// Southern Africa, where every centre sits today. The map opens fitted to this
/// box and can be panned anywhere.
final class SouthernAfricaBounds {
  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(-34.9, 15.9),
    const LatLng(-22.0, 33.2),
  );
  static const LatLng centre = LatLng(-28.5, 24.5);
  static const double initialZoom = 5.0;
}

/// The dark OpenStreetMap-based map on the Centres tab.
///
/// Blue pins are centres, the gold pin is Ekuphumuleni, and pins cluster when
/// the map is zoomed out.
class CentresMap extends ConsumerStatefulWidget {
  const CentresMap({
    super.key,
    required this.centres,
    this.height = 320,
    this.focusedCentreId,
    this.userPoint,
  });

  /// Centres to plot (those without coordinates are skipped).
  final List<Centre> centres;

  /// Height of the map in logical pixels.
  final double height;

  /// When this changes the map flies to that centre.
  final String? focusedCentreId;

  /// The user's position, drawn as a soft blue dot.
  final GeoPoint? userPoint;

  @override
  ConsumerState<CentresMap> createState() => _CentresMapState();
}

class _CentresMapState extends ConsumerState<CentresMap> {
  final MapController _mapController = MapController();
  static const double _minZoom = 3.0;
  static const double _maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitSouthernAfrica());
  }

  @override
  void didUpdateWidget(CentresMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedCentreId != null &&
        widget.focusedCentreId != oldWidget.focusedCentreId) {
      _focusOn(widget.focusedCentreId!);
    }
  }

  void _fitSouthernAfrica() {
    if (!mounted) {
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: SouthernAfricaBounds.bounds,
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  void _focusOn(String id) {
    final Centre? centre = widget.centres
        .cast<Centre?>()
        .firstWhere((Centre? c) => c?.id == id, orElse: () => null);
    if (centre == null || !centre.hasCoordinates) {
      return;
    }
    _mapController.move(
      LatLng(centre.lat!, centre.lng!),
      14.0.clamp(_minZoom, _maxZoom).toDouble(),
    );
  }

  void _zoomBy(double delta) {
    final double zoom =
        (_mapController.camera.zoom + delta).clamp(_minZoom, _maxZoom).toDouble();
    _mapController.move(_mapController.camera.center, zoom);
  }

  List<Marker> _markers() {
    return <Marker>[
      for (final Centre centre in widget.centres)
        if (centre.hasCoordinates)
          Marker(
            point: LatLng(centre.lat!, centre.lng!),
            width: 34,
            height: 44,
            alignment: Alignment.bottomCenter,
            child: Semantics(
              button: true,
              label: '${centre.name}, ${centre.region}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openCentre(centre),
                child: _Pin(
                  highlighted: centre.id == widget.focusedCentreId,
                  icon: Icons.place_rounded,
                ),
              ),
            ),
          ),
    ];
  }

  void _openCentre(Centre centre) {
    showCentreSheet(
      context: context,
      centre: centre,
      userPoint: ref.read(effectiveLocationProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<bool> online = ref.watch(onlineProvider);
    final bool offline = online.valueOrNull == false;

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: SouthernAfricaBounds.centre,
                  initialZoom: SouthernAfricaBounds.initialZoom,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  backgroundColor: AppColors.surface,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const <String>['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.tshk.tshk_compass',
                    maxNativeZoom: 19,
                  ),
                  if (widget.userPoint != null)
                    CircleLayer(
                      circles: <CircleMarker>[
                        CircleMarker(
                          point: LatLng(widget.userPoint!.latitude,
                              widget.userPoint!.longitude),
                          radius: 40,
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderColor: AppColors.accent,
                          borderStrokeWidth: 1.5,
                          useRadiusInMeter: true,
                        ),
                      ],
                    ),
                  // Ekuphumuleni: always a distinct gold pin, never clustered.
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: LatLng(
                          Ekuphumuleni.latitude,
                          Ekuphumuleni.longitude,
                        ),
                        width: 40,
                        height: 50,
                        alignment: Alignment.bottomCenter,
                        child: Semantics(
                          label: '${S.ekuphumuleni.en}, ${S.spiritualCapital.en}',
                          child: const _Pin(
                            gold: true,
                            icon: Icons.star_rounded,
                            elevated: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Centres, clustered when zoomed out.
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45,
                      size: const Size(38, 38),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(40),
                      maxZoom: 15,
                      // Our pins handle their own taps, so the cluster layer
                      // must not wrap them in another gesture detector.
                      markerChildBehavior: true,
                      markers: _markers(),
                      builder: (BuildContext context, List<Marker> markers) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.75),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${markers.length}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  RichAttributionWidget(
                    attributions: <SourceAttribution>[
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => NavigationLauncher.openWeb(
                          'https://www.openstreetmap.org/copyright',
                        ),
                      ),
                      TextSourceAttribution(
                        'CARTO',
                        onTap: () => NavigationLauncher.openWeb(
                          'https://carto.com/attributions',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Zoom controls.
            Positioned(
              right: 10,
              bottom: 46,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ZoomButton(
                    icon: Icons.add,
                    tooltip: S.zoomIn,
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _ZoomButton(
                    icon: Icons.remove,
                    tooltip: S.zoomOut,
                    onTap: () => _zoomBy(-1),
                  ),
                ],
              ),
            ),

            // Friendly offline message: the list below still works.
            if (offline)
              Positioned.fill(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.72),
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.textSecondary, size: 26),
                        const SizedBox(height: 10),
                        Text(
                          '${S.offlineMap.en} · ${S.offlineMap.zu}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(onlineProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            '${S.retry.en} · ${S.retry.zu}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Bi tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tooltip.en}, ${tooltip.zu}',
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// A map pin: blue for centres, gold for Ekuphumuleni.
class _Pin extends StatelessWidget {
  const _Pin({
    this.gold = false,
    this.highlighted = false,
    this.elevated = false,
    required this.icon,
  });

  final bool gold;
  final bool highlighted;
  final bool elevated;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final Color main = gold ? AppColors.gold : AppColors.accent;
    return SizedBox(
      width: elevated ? 40 : 34,
      height: elevated ? 50 : 44,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          if (highlighted || elevated)
            Container(
              width: (elevated ? 40 : 34) + (highlighted ? 10 : 4),
              height: (elevated ? 40 : 34) + (highlighted ? 10 : 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: main.withValues(alpha: 0.18),
              ),
            ),
          Icon(
            icon,
            size: elevated ? 40 : 34,
            color: main,
            shadows: <Shadow>[
              Shadow(
                color: AppColors.background.withValues(alpha: 0.9),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
