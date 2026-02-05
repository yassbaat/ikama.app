import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/geo_location.dart';
import '../../data/repositories/robust_mosque_repository.dart';

// Events
abstract class MosqueEvent extends Equatable {
  const MosqueEvent();
  @override
  List<Object?> get props => [];
}

class LoadMosques extends MosqueEvent {}

class SearchMosques extends MosqueEvent {
  final String query;
  const SearchMosques(this.query);
  @override
  List<Object?> get props => [query];
}

class LoadNearbyMosques extends MosqueEvent {
  final GeoLocation location;
  const LoadNearbyMosques(this.location);
  @override
  List<Object?> get props => [location];
}

class SelectMosque extends MosqueEvent {
  final Mosque mosque;
  const SelectMosque(this.mosque);
  @override
  List<Object?> get props => [mosque];
}

class SetActiveMosque extends MosqueEvent {
  final String mosqueId;
  const SetActiveMosque(this.mosqueId);
  @override
  List<Object?> get props => [mosqueId];
}

class ToggleFavorite extends MosqueEvent {
  final String mosqueId;
  const ToggleFavorite(this.mosqueId);
  @override
  List<Object?> get props => [mosqueId];
}

class RefreshMosques extends MosqueEvent {}

// States
abstract class MosqueState extends Equatable {
  const MosqueState();
  @override
  List<Object?> get props => [];
}

class MosqueInitial extends MosqueState {}

class MosqueLoading extends MosqueState {}

class MosquesLoaded extends MosqueState {
  final List<Mosque> mosques;
  final Mosque? activeMosque;
  final Mosque? selectedMosque;
  final bool isOffline;
  final String? warningMessage;

  const MosquesLoaded({
    required this.mosques,
    this.activeMosque,
    this.selectedMosque,
    this.isOffline = false,
    this.warningMessage,
  });

  MosquesLoaded copyWith({
    List<Mosque>? mosques,
    Mosque? activeMosque,
    Mosque? selectedMosque,
    bool? isOffline,
    String? warningMessage,
  }) {
    return MosquesLoaded(
      mosques: mosques ?? this.mosques,
      activeMosque: activeMosque ?? this.activeMosque,
      selectedMosque: selectedMosque ?? this.selectedMosque,
      isOffline: isOffline ?? this.isOffline,
      warningMessage: warningMessage ?? this.warningMessage,
    );
  }

  @override
  List<Object?> get props => [
    mosques, activeMosque, selectedMosque, isOffline, warningMessage,
  ];
}

class MosqueSearchResults extends MosqueState {
  final List<Mosque> results;
  final String query;
  final bool isOffline;

  const MosqueSearchResults(
    this.results,
    this.query, {
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [results, query, isOffline];
}

class NearbyMosquesLoaded extends MosqueState {
  final List<Mosque> mosques;
  final GeoLocation location;
  final bool isOffline;

  const NearbyMosquesLoaded(
    this.mosques,
    this.location, {
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [mosques, location, isOffline];
}

class MosqueError extends MosqueState {
  final String message;
  final bool isRecoverable;
  final String? errorCode;

  const MosqueError({
    required this.message,
    this.isRecoverable = true,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, isRecoverable, errorCode];
}

// BLoC
class MosqueBloc extends Bloc<MosqueEvent, MosqueState> {
  final RobustMosqueRepository _repository;
  final AppLogger _logger;

  MosqueBloc({
    required RobustMosqueRepository repository,
    AppLogger? logger,
  })  : _repository = repository,
        _logger = logger ?? AppLogger(),
        super(MosqueInitial()) {
    on<LoadMosques>(_onLoadMosques);
    on<SearchMosques>(_onSearchMosques);
    on<LoadNearbyMosques>(_onLoadNearbyMosques);
    on<SelectMosque>(_onSelectMosque);
    on<SetActiveMosque>(_onSetActiveMosque);
    on<ToggleFavorite>(_onToggleFavorite);
    on<RefreshMosques>(_onRefreshMosques);
  }

  Future<void> _onLoadMosques(
    LoadMosques event,
    Emitter<MosqueState> emit,
  ) async {
    _logger.d('Loading mosques');
    emit(MosqueLoading());
    
    try {
      final favorites = await _repository.getFavoriteMosques();
      final active = await _repository.getActiveMosque();
      
      emit(MosquesLoaded(
        mosques: favorites,
        activeMosque: active,
      ));
      
      _logger.i('Loaded ${favorites.length} favorite mosques');
    } on DatabaseException catch (e) {
      _logger.e('Database error loading mosques', error: e);
      emit(MosqueError(
        message: 'Failed to load saved mosques. Please try again.',
        errorCode: 'DATABASE_ERROR',
      ));
    } catch (e) {
      _logger.e('Unexpected error loading mosques', error: e);
      emit(MosqueError(
        message: 'An unexpected error occurred. Please try again.',
        errorCode: 'UNKNOWN_ERROR',
      ));
    }
  }

  Future<void> _onSearchMosques(
    SearchMosques event,
    Emitter<MosqueState> emit,
  ) async {
    // Validate query
    final validation = Validators.searchQuery(event.query);
    if (!validation.isValid) {
      emit(MosqueError(
        message: validation.errorMessage ?? 'Invalid search query',
        isRecoverable: true,
      ));
      return;
    }

    if (event.query.isEmpty) {
      add(LoadMosques());
      return;
    }

    _logger.d('Searching mosques', data: {'query': event.query});
    emit(MosqueLoading());
    
    try {
      final results = await _repository.searchMosques(
        event.query,
        useCacheOnError: true,
      );
      
      emit(MosqueSearchResults(results, event.query));
      _logger.i('Search found ${results.length} mosques');
    } on NoConnectionException catch (e) {
      _logger.w('Search failed - no connection', error: e);
      // Still show results from cache
      final results = await _repository.searchMosques(
        event.query,
        useCacheOnError: true,
      );
      emit(MosqueSearchResults(
        results,
        event.query,
        isOffline: true,
      ));
    } on RepositoryException catch (e) {
      _logger.e('Repository error during search', error: e);
      emit(MosqueError(
        message: e.message,
        errorCode: 'SEARCH_ERROR',
      ));
    } catch (e) {
      _logger.e('Unexpected error during search', error: e);
      emit(MosqueError(
        message: 'Search failed. Please try again.',
        errorCode: 'UNKNOWN_ERROR',
      ));
    }
  }

  Future<void> _onLoadNearbyMosques(
    LoadNearbyMosques event,
    Emitter<MosqueState> emit,
  ) async {
    // Validate coordinates
    final validation = Validators.geoLocation(event.location);
    if (!validation.isValid) {
      emit(MosqueError(
        message: 'Invalid location data',
        errorCode: 'INVALID_LOCATION',
      ));
      return;
    }

    _logger.d('Loading nearby mosques', data: {
      'lat': event.location.latitude,
      'lng': event.location.longitude,
    });
    
    emit(MosqueLoading());
    
    try {
      final mosques = await _repository.getNearbyMosques(
        event.location,
        useCacheOnError: true,
      );
      
      emit(NearbyMosquesLoaded(mosques, event.location));
      _logger.i('Found ${mosques.length} nearby mosques');
    } on NoConnectionException catch (e) {
      _logger.w('Nearby search failed - no connection', error: e);
      final mosques = await _repository.getNearbyMosques(
        event.location,
        useCacheOnError: true,
      );
      emit(NearbyMosquesLoaded(
        mosques,
        event.location,
        isOffline: true,
      ));
    } catch (e) {
      _logger.e('Error loading nearby mosques', error: e);
      emit(MosqueError(
        message: 'Failed to load nearby mosques. Please try again.',
        errorCode: 'NEARBY_ERROR',
      ));
    }
  }

  Future<void> _onSelectMosque(
    SelectMosque event,
    Emitter<MosqueState> emit,
  ) async {
    _logger.d('Selecting mosque', data: {'mosqueId': event.mosque.id});
    
    if (state is MosquesLoaded) {
      final current = state as MosquesLoaded;
      emit(current.copyWith(selectedMosque: event.mosque));
    }
  }

  Future<void> _onSetActiveMosque(
    SetActiveMosque event,
    Emitter<MosqueState> emit,
  ) async {
    _logger.d('Setting active mosque', data: {'mosqueId': event.mosqueId});
    
    try {
      await _repository.setActiveMosque(event.mosqueId);
      add(LoadMosques());
    } catch (e) {
      _logger.e('Failed to set active mosque', error: e);
      emit(MosqueError(
        message: 'Failed to set active mosque. Please try again.',
        errorCode: 'SET_ACTIVE_ERROR',
      ));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<MosqueState> emit,
  ) async {
    _logger.d('Toggling favorite', data: {'mosqueId': event.mosqueId});
    
    try {
      final favorites = await _repository.getFavoriteMosques();
      final isFavorite = favorites.any((m) => m.id == event.mosqueId);
      
      await _repository.setFavorite(event.mosqueId, !isFavorite);
      add(LoadMosques());
    } catch (e) {
      _logger.e('Failed to toggle favorite', error: e);
      emit(MosqueError(
        message: 'Failed to update favorites. Please try again.',
        errorCode: 'FAVORITE_ERROR',
      ));
    }
  }

  Future<void> _onRefreshMosques(
    RefreshMosques event,
    Emitter<MosqueState> emit,
  ) async {
    add(LoadMosques());
  }

  @override
  Future<void> close() {
    _logger.d('MosqueBloc closed');
    return super.close();
  }
}
