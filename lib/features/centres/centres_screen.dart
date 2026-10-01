import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/centre.dart';
import '../../data/repositories/centres_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header.dart';
import '../../widgets/localized_text.dart';
import '../../widgets/cards.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/language_scope.dart';
import '../location/location_controller.dart';
import 'centres_providers.dart';
import 'widgets/centre_card.dart';
import 'widgets/centres_map.dart';

/// The Centres tab: map, search, nearest, and the list grouped by region.
class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});

  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _focusedCentreId;
  bool _sortedByDistance = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(centreSearchProvider.notifier).update(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Centre>> centresAsync =
        ref.watch(centresListProvider);
    final AsyncValue<List<RegionGroup>> groupsAsync =
        ref.watch(regionGroupsProvider);
    final AsyncValue<List<Centre>> byDistanceAsync =
        ref.watch(centresByDistanceProvider);
    final NearestCentre? nearest = ref.watch(nearestCentreProvider);
    final GeoPoint? userPoint = ref.watch(effectiveLocationProvider);
    final String query = ref.watch(centreSearchProvider);
    final CentresData? data = ref.watch(centresProvider).valueOrNull;

    final List<Centre> allCentres = centresAsync.valueOrNull ?? <Centre>[];

    // Nothing to show: say *why* (no connection yet, or the server sent an
    // empty list) rather than "no results", which only fits a search.
    final bool nothingDownloaded =
        data == null || data.offline || data.blocked;
    final Bi emptyMessage = allCentres.isNotEmpty
        ? S.noResults
        : nothingDownloaded
            ? S.centresOffline
            : S.centresEmpty;

    return SafeArea(
      bottom: false,
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                const AppHeader(),
                const SizedBox(height: 16),

                // Map.
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppLayout.cardRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CentresMap(
                    centres: allCentres,
                    height: 320,
                    focusedCentreId: _focusedCentreId,
                    userPoint: userPoint,
                  ),
                ),
                const SizedBox(height: 10),
                LocalizedText(
                  S.mapCaption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),

                // Search + nearest.
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: S.searchCentre.text,
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: S.close.text,
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(centreSearchProvider.notifier)
                                  .clear();
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: S.nearest,
                  icon: Icons.near_me_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: nearest == null
                      ? () => _requestLocation(context)
                      : () => _goToNearest(nearest),
                  expand: true,
                ),
                if (nearest != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    S
                        .nearestCentreValue(
                          nearest.centre.name,
                          Formatters.distanceKm(nearest.distanceKm),
                        )
                        .text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
                const SizedBox(height: 20),

                // Grouped list.
                LocalizedText(
                  S.allCentres,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),

                if (groupsAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (groupsAsync.hasError)
                  SectionCard(
                    child: LocalizedText(
                      S.centresFailed,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else if (_sortedByDistance)
                  _buildDistanceList(byDistanceAsync, emptyMessage)
                else
                  _buildRegionList(groupsAsync, emptyMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionList(
    AsyncValue<List<RegionGroup>> groupsAsync,
    Bi emptyMessage,
  ) {
    final List<RegionGroup> groups = groupsAsync.valueOrNull ?? <RegionGroup>[];
    if (groups.isEmpty) {
      return SectionCard(
        child: LocalizedText(
          emptyMessage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final RegionGroup group in groups) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: SectionHeader(
              title: group.region,
              count: group.count,
            ),
          ),
          for (final Centre centre in group.centres) ...<Widget>[
            CentreCard(
              key: ValueKey<String>(centre.id),
              centre: centre,
              highlighted: centre.id == _focusedCentreId,
              distanceKm: _distanceTo(centre),
              onShowOnMap: centre.hasCoordinates
                  ? () => _showOnMap(centre)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildDistanceList(
    AsyncValue<List<Centre>> byDistanceAsync,
    Bi emptyMessage,
  ) {
    final List<Centre> centres =
        byDistanceAsync.valueOrNull ?? <Centre>[];
    if (centres.isEmpty) {
      return SectionCard(
        child: LocalizedText(
          emptyMessage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SectionHeader(title: S.nearest.text, count: centres.length),
        ),
        for (final Centre centre in centres) ...<Widget>[
          CentreCard(
            key: ValueKey<String>(centre.id),
            centre: centre,
            highlighted: centre.id == _focusedCentreId,
            distanceKm: _distanceTo(centre),
            onShowOnMap:
                centre.hasCoordinates ? () => _showOnMap(centre) : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  double? _distanceTo(Centre centre) {
    final GeoPoint? userPoint = ref.read(effectiveLocationProvider);
    if (userPoint == null || !centre.hasCoordinates) {
      return null;
    }
    return GeoMath.distanceBetweenKm(userPoint, centre.point!);
  }

  Future<void> _requestLocation(BuildContext context) async {
    await ref.read(locationControllerProvider.notifier).startTracking();
    if (!context.mounted) {
      return;
    }
    final bool hasPoint = ref.read(effectiveLocationProvider) != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasPoint ? S.nearest.text : S.locationNotSet.text,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  void _goToNearest(NearestCentre nearest) {
    setState(() {
      _sortedByDistance = true;
      _focusedCentreId = nearest.centre.id;
    });
    _scrollToTop();
  }

  void _showOnMap(Centre centre) {
    setState(() => _focusedCentreId = centre.id);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}
