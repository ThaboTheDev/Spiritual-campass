import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/geo/coordinates.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/map_config.dart';
import '../../../core/perf/performance_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/centre.dart';
import '../../../services/navigation_launcher.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/nine_pointed_star.dart';
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
/// Blue pins are centres and the gold nine-pointed star is Ekuphumuleni. All
/// location pins are displayed simultaneously.
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

  bool _hasTileError = false;

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

  void _openEkuphumuleni() {
    showEkuphumuleniSheet(
      context: context,
      userPoint: ref.read(effectiveLocationProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final AsyncValue<bool> online = ref.watch(onlineProvider);
    final bool offline = online.valueOrNull == false;
    final PerfSettings perf = ref.watch(perfSettingsProvider);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: SouthernAfricaBounds.centre,
                  initialZoom: SouthernAfricaBounds.initialZoom,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  backgroundColor: AppColors.surface,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: MapConfig.tileUrlTemplate,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                    maxNativeZoom: MapConfig.maxNativeZoom,
                    // Optional size-capped tile cache (about 50 MB); off in
                    // the low profile to save storage and I/O.
                    tileProvider: NetworkTileProvider(
                      cachingProvider: perf.tileCacheEnabled
                          ? BuiltInMapCachingProvider.getOrCreateInstance(
                              maxCacheSize: kTileCacheMaxBytes,
                            )
                          : const DisabledMapCachingProvider(),
                    ),
                    // Keep the tiles light on weak GPUs: skip fade-in.
                    tileDisplay: perf.animate
                        ? const TileDisplay.fadeIn()
                        : const TileDisplay.instantaneous(),
                    tileBuilder: (BuildContext context, Widget tileWidget, TileImage tile) {
                      return ColorFiltered(
                        colorFilter: MapConfig.darkMapFilter,
                        child: tileWidget,
                      );
                    },
                    errorTileCallback: (TileImage tile, Object error, StackTrace? stackTrace) {
                      if (!_hasTileError && mounted) {
                        setState(() {
                          _hasTileError = true;
                        });
                      }
                    },
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
                  // Centres: all location pins shown at once.
                  MarkerLayer(
                    markers: _markers(),
                  ),
                  // Ekuphumuleni: always a distinct gold nine-pointed star.
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: const LatLng(
                          Ekuphumuleni.latitude,
                          Ekuphumuleni.longitude,
                        ),
                        width: 44,
                        height: 52,
                        alignment: Alignment.bottomCenter,
                        child: Semantics(
                          button: true,
                          label: '${S.ekuphumuleni.en}, ${S.spiritualCapital.en}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openEkuphumuleni,
                            child: const _Pin(
                              gold: true,
                              elevated: true,
                              child: NinePointedStar(
                                size: 40,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: <SourceAttribution>[
                      TextSourceAttribution(
                        MapConfig.osmAttributionText,
                        onTap: () => NavigationLauncher.openWeb(
                          MapConfig.osmAttributionUrl,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),

            // Subtle fallback overlay when tiles fail to load (offline or blocked).
            // Positioned behind zoom controls and lets user interact while pins remain visible on dark surface.
            if (_hasTileError && !offline)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            MapConfig.fallbackMessage,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          S.offlineMap.inline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasTileError = false;
                            });
                            ref.invalidate(onlineProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            S.retry.inline,
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
      label: '${tooltip.en}, ${tooltip.secondary}',
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

/// A map pin: blue for centres, gold nine-pointed star for Ekuphumuleni.
class _Pin extends StatelessWidget {
  const _Pin({
    this.gold = false,
    this.highlighted = false,
    this.elevated = false,
    this.icon,
    this.child,
  }) : assert(icon != null || child != null);

  final bool gold;
  final bool highlighted;
  final bool elevated;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Color main = gold ? AppColors.gold : AppColors.accent;
    final double iconSize = elevated ? 40 : 34;
    return SizedBox(
      width: elevated ? 44 : 34,
      height: elevated ? 52 : 44,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          if (highlighted || elevated)
            Container(
              width: iconSize + (highlighted ? 10 : 4),
              height: iconSize + (highlighted ? 10 : 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: main.withValues(alpha: 0.18),
              ),
            ),
          if (child != null)
            child!
          else
            Icon(
              icon,
              size: iconSize,
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
