import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/town.dart';
import '../../data/repositories/towns_repository.dart';

/// The towns asset loader.
final Provider<TownsRepository> townsRepositoryProvider =
    Provider<TownsRepository>((ref) => TownsRepository());

/// The grouped town list, loaded on first use (the Location tab).
final FutureProvider<List<TownGroup>> townsProvider =
    FutureProvider<List<TownGroup>>(
  (ref) => ref.watch(townsRepositoryProvider).load(),
);
