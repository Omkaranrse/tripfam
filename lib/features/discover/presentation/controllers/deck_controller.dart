import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../account/data/auth_repository.dart';
import '../../../chats/data/chat_repository.dart';
import '../../../trips/data/saved_trip_repository.dart';
import '../../../trips/data/trip_repository.dart';
import '../../../trips/domain/trip.dart';
import '../../../trips/domain/trip_filter.dart';
import '../../data/dismissed_trips_storage.dart';
import '../../domain/deck_config.dart';

class DeckUndoAction {
  const DeckUndoAction({
    required this.trip,
    required this.action,
  });

  final Trip trip;
  final SwipeAction action;
}

class DeckState {
  const DeckState({
    this.trips = const [],
    this.currentIndex = 0,
    this.undoStack = const [],
    this.isLoading = false,
    this.isPrefetching = false,
    this.errorMessage,
    this.isDeckMode = true,
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.savedTripIds = const {},
    this.dismissedTripIds = const {},
    this.hasMore = true,
    this.pageOffset = 0,
  });

  final List<Trip> trips;
  final int currentIndex;
  final List<DeckUndoAction> undoStack;
  final bool isLoading;
  final bool isPrefetching;
  final String? errorMessage;
  final bool isDeckMode;
  final String selectedCategory;
  final String searchQuery;
  final Set<String> savedTripIds;
  final Set<String> dismissedTripIds;
  final bool hasMore;
  final int pageOffset;

  /// Trips remaining from currentIndex onwards
  List<Trip> get remainingTrips =>
      currentIndex < trips.length ? trips.sublist(currentIndex) : const [];

  Trip? get currentTrip =>
      (currentIndex >= 0 && currentIndex < trips.length) ? trips[currentIndex] : null;

  bool get canUndo => undoStack.isNotEmpty;

  DeckState copyWith({
    List<Trip>? trips,
    int? currentIndex,
    List<DeckUndoAction>? undoStack,
    bool? isLoading,
    bool? isPrefetching,
    String? errorMessage,
    bool clearError = false,
    bool? isDeckMode,
    String? selectedCategory,
    String? searchQuery,
    Set<String>? savedTripIds,
    Set<String>? dismissedTripIds,
    bool? hasMore,
    int? pageOffset,
  }) {
    return DeckState(
      trips: trips ?? this.trips,
      currentIndex: currentIndex ?? this.currentIndex,
      undoStack: undoStack ?? this.undoStack,
      isLoading: isLoading ?? this.isLoading,
      isPrefetching: isPrefetching ?? this.isPrefetching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isDeckMode: isDeckMode ?? this.isDeckMode,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      savedTripIds: savedTripIds ?? this.savedTripIds,
      dismissedTripIds: dismissedTripIds ?? this.dismissedTripIds,
      hasMore: hasMore ?? this.hasMore,
      pageOffset: pageOffset ?? this.pageOffset,
    );
  }
}

class DeckController extends StateNotifier<DeckState> {
  DeckController(this._ref) : super(const DeckState(isLoading: true)) {
    loadInitial();
  }

  final Ref _ref;
  static const int _batchSize = 10;

  TripRepository get _tripRepo => _ref.read(tripRepositoryProvider);
  SavedTripRepository get _savedRepo => _ref.read(savedTripRepositoryProvider);
  DismissedTripsStorage get _dismissedStorage =>
      _ref.read(dismissedTripsStorageProvider);

  /// Loads the initial batch of trips honoring exclusion rules
  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final savedIds = await _savedRepo.getSavedTripIds();
      final dismissedIds = _dismissedStorage.getDismissedTripIds();

      final trips = await _fetchBatch(
        offset: 0,
        savedIds: savedIds,
        dismissedIds: dismissedIds,
      );

      state = state.copyWith(
        trips: trips,
        currentIndex: 0,
        savedTripIds: savedIds,
        dismissedTripIds: dismissedIds,
        isLoading: false,
        pageOffset: trips.length,
        hasMore: trips.length >= _batchSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load trips: ${e.toString()}',
      );
    }
  }

  /// Prefetches next batch when remaining cards in deck are low
  Future<void> prefetchIfNeeded() async {
    if (state.isPrefetching || !state.hasMore || state.isLoading) return;
    final remaining = state.trips.length - state.currentIndex;
    if (remaining > 3) return;

    state = state.copyWith(isPrefetching: true);
    try {
      final newBatch = await _fetchBatch(
        offset: state.pageOffset,
        savedIds: state.savedTripIds,
        dismissedIds: state.dismissedTripIds,
      );

      // Append distinct trips
      final existingIds = state.trips.map((t) => t.id).toSet();
      final filteredNew = newBatch.where((t) => !existingIds.contains(t.id)).toList();

      state = state.copyWith(
        trips: [...state.trips, ...filteredNew],
        pageOffset: state.pageOffset + newBatch.length,
        hasMore: newBatch.length >= _batchSize,
        isPrefetching: false,
      );
    } catch (_) {
      state = state.copyWith(isPrefetching: false);
    }
  }

  /// Internal helper that queries trips and applies all 6 exclusion rules
  Future<List<Trip>> _fetchBatch({
    required int offset,
    required Set<String> savedIds,
    required Set<String> dismissedIds,
  }) async {
    Set<String> blockedUsers;
    try {
      blockedUsers = await _ref.read(blockedUsersProvider.future);
    } catch (_) {
      blockedUsers = _ref.read(blockedUsersProvider).value ?? const <String>{};
    }
    final currentUserId = _ref.read(authRepositoryProvider).currentUser?.id;

    TripFilter? filter;
    final tags = <String>{};
    if (state.selectedCategory != 'All') {
      tags.add(state.selectedCategory);
    }

    if (state.searchQuery.trim().isNotEmpty || tags.isNotEmpty) {
      filter = TripFilter(
        destinationQuery:
            state.searchQuery.trim().isNotEmpty ? state.searchQuery.trim() : null,
        tags: tags,
      );
    }

    final rawTrips = await _tripRepo.getDiscoverTrips(
      filter: filter,
      limit: _batchSize * 2, // overfetch slightly to account for exclusions
      offset: offset,
    );

    final now = DateTime.now();

    // Exclusion rules:
    // 1. User's own trips
    // 2. Saved trips
    // 3. Dismissed trips
    // 4. Full trips (availablePlaces <= 0)
    // 5. Past trips (endDate < now)
    // 6. Blocked users
    return rawTrips.where((trip) {
      if (currentUserId != null && trip.hostId == currentUserId) return false;
      if (savedIds.contains(trip.id)) return false;
      if (dismissedIds.contains(trip.id)) return false;
      if (trip.availablePlaces <= 0) return false;
      if (trip.endDate.isBefore(now)) return false;
      if (blockedUsers.contains(trip.hostId)) return false;
      return true;
    }).toList();
  }

  /// Swipes in a direction (Left or Right) committing save or dismiss
  Future<Trip?> swipe(SwipeDirection direction) async {
    final trip = state.currentTrip;
    if (trip == null) return null;

    final action = direction.action;
    final updatedUndoStack = List<DeckUndoAction>.from(state.undoStack)
      ..add(DeckUndoAction(trip: trip, action: action));

    if (action == SwipeAction.save) {
      final updatedSaved = Set<String>.from(state.savedTripIds)..add(trip.id);
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        savedTripIds: updatedSaved,
        undoStack: updatedUndoStack,
      );
      await _savedRepo.saveTrip(trip.id);
    } else {
      final updatedDismissed = Set<String>.from(state.dismissedTripIds)..add(trip.id);
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        dismissedTripIds: updatedDismissed,
        undoStack: updatedUndoStack,
      );
      await _dismissedStorage.dismissTrip(trip.id);
    }

    unawaited(prefetchIfNeeded());
    return trip;
  }

  /// Reverses the most recent swipe action
  Future<Trip?> undo() async {
    if (state.undoStack.isEmpty) return null;

    final last = state.undoStack.last;
    final updatedUndoStack = List<DeckUndoAction>.from(state.undoStack)..removeLast();

    if (last.action == SwipeAction.save) {
      final updatedSaved = Set<String>.from(state.savedTripIds)..remove(last.trip.id);
      state = state.copyWith(
        currentIndex: (state.currentIndex > 0) ? state.currentIndex - 1 : 0,
        savedTripIds: updatedSaved,
        undoStack: updatedUndoStack,
      );
      await _savedRepo.unsaveTrip(last.trip.id);
    } else {
      final updatedDismissed = Set<String>.from(state.dismissedTripIds)..remove(last.trip.id);
      state = state.copyWith(
        currentIndex: (state.currentIndex > 0) ? state.currentIndex - 1 : 0,
        dismissedTripIds: updatedDismissed,
        undoStack: updatedUndoStack,
      );
      await _dismissedStorage.removeDismissedTrip(last.trip.id);
    }

    return last.trip;
  }

  /// Jump directly to a trip (used when tapping thumbnail in upcoming strip)
  void jumpToTrip(String tripId) {
    final idx = state.trips.indexWhere((t) => t.id == tripId);
    if (idx != -1 && idx >= state.currentIndex) {
      state = state.copyWith(currentIndex: idx);
    }
  }

  /// Toggles view between stacked deck and grid
  void toggleViewMode() {
    state = state.copyWith(isDeckMode: !state.isDeckMode);
  }

  /// Sets grid or deck view explicitly
  void setDeckMode(bool isDeck) {
    state = state.copyWith(isDeckMode: isDeck);
  }

  /// Selects category chip and reloads deck
  void selectCategory(String category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category);
    loadInitial();
  }

  /// Updates search query and reloads deck
  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadInitial();
  }

  /// Resets skipped trips locally and re-evaluates deck
  Future<void> resetSkippedTrips() async {
    await _dismissedStorage.clearAll();
    await loadInitial();
  }
}

final deckControllerProvider =
    StateNotifierProvider<DeckController, DeckState>((ref) {
  return DeckController(ref);
});

final savedTripsProvider = FutureProvider<List<Trip>>((ref) {
  return ref.watch(savedTripRepositoryProvider).getSavedTrips();
});
