import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/robust_mosque_repository.dart';
import '../../data/local/preferences_service.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/services/prayer_engine.dart';

// Events
abstract class PrayerTimesEvent extends Equatable {
  const PrayerTimesEvent();
  @override
  List<Object?> get props => [];
}

class LoadPrayerTimes extends PrayerTimesEvent {
  final String mosqueId;
  final bool forceRefresh;
  const LoadPrayerTimes(this.mosqueId, {this.forceRefresh = false});
  @override
  List<Object?> get props => [mosqueId, forceRefresh];
}

class RefreshPrayerTimes extends PrayerTimesEvent {
  final String mosqueId;
  const RefreshPrayerTimes(this.mosqueId);
  @override
  List<Object?> get props => [mosqueId];
}

class UpdateCurrentTime extends PrayerTimesEvent {
  final DateTime now;
  const UpdateCurrentTime(this.now);
  @override
  List<Object?> get props => [now];
}

class SetTravelTime extends PrayerTimesEvent {
  final String mosqueId;
  final int seconds;
  const SetTravelTime(this.mosqueId, this.seconds);
  @override
  List<Object?> get props => [mosqueId, seconds];
}

class LoadCachedData extends PrayerTimesEvent {
  final String mosqueId;
  const LoadCachedData(this.mosqueId);
  @override
  List<Object?> get props => [mosqueId];
}

// States
abstract class PrayerTimesState extends Equatable {
  const PrayerTimesState();
  @override
  List<Object?> get props => [];
}

class PrayerTimesInitial extends PrayerTimesState {}

class PrayerTimesLoading extends PrayerTimesState {}

class PrayerTimesLoaded extends PrayerTimesState {
  final PrayerTimes prayerTimes;
  final NextPrayerResult nextPrayer;
  final RakahEstimate? currentRakah;
  final TravelPrediction? travelPrediction;
  final int travelTimeSeconds;
  final bool isUsingCache;
  final DateTime? lastUpdated;
  final String? warningMessage;

  const PrayerTimesLoaded({
    required this.prayerTimes,
    required this.nextPrayer,
    this.currentRakah,
    this.travelPrediction,
    this.travelTimeSeconds = 0,
    this.isUsingCache = false,
    this.lastUpdated,
    this.warningMessage,
  });

  PrayerTimesLoaded copyWith({
    PrayerTimes? prayerTimes,
    NextPrayerResult? nextPrayer,
    RakahEstimate? currentRakah,
    TravelPrediction? travelPrediction,
    int? travelTimeSeconds,
    bool? isUsingCache,
    DateTime? lastUpdated,
    String? warningMessage,
  }) {
    return PrayerTimesLoaded(
      prayerTimes: prayerTimes ?? this.prayerTimes,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      currentRakah: currentRakah ?? this.currentRakah,
      travelPrediction: travelPrediction ?? this.travelPrediction,
      travelTimeSeconds: travelTimeSeconds ?? this.travelTimeSeconds,
      isUsingCache: isUsingCache ?? this.isUsingCache,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      warningMessage: warningMessage ?? this.warningMessage,
    );
  }

  @override
  List<Object?> get props => [
    prayerTimes, nextPrayer, currentRakah, travelPrediction,
    travelTimeSeconds, isUsingCache, lastUpdated, warningMessage,
  ];
}

class PrayerTimesError extends PrayerTimesState {
  final String message;
  final PrayerTimes? cachedData;
  final bool isRecoverable;
  final String? errorCode;

  const PrayerTimesError({
    required this.message,
    this.cachedData,
    this.isRecoverable = true,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, cachedData, isRecoverable, errorCode];
}

// BLoC
class PrayerTimesBloc extends Bloc<PrayerTimesEvent, PrayerTimesState> {
  final RobustMosqueRepository _repository;
  final PreferencesService _preferences;
  final PrayerEngine _engine;
  final AppLogger _logger;
  Timer? _timer;
  String? _currentMosqueId;

  PrayerTimesBloc({
    required RobustMosqueRepository repository,
    required PreferencesService preferences,
    PrayerEngine? engine,
    AppLogger? logger,
  })  : _repository = repository,
        _preferences = preferences,
        _engine = engine ?? PrayerEngine(config: preferences.getPrayerEngineConfig()),
        _logger = logger ?? AppLogger(),
        super(PrayerTimesInitial()) {
    on<LoadPrayerTimes>(_onLoadPrayerTimes);
    on<RefreshPrayerTimes>(_onRefreshPrayerTimes);
    on<UpdateCurrentTime>(_onUpdateCurrentTime);
    on<SetTravelTime>(_onSetTravelTime);
    on<LoadCachedData>(_onLoadCachedData);
  }

  Future<void> _onLoadPrayerTimes(
    LoadPrayerTimes event,
    Emitter<PrayerTimesState> emit,
  ) async {
    _logger.d('Loading prayer times', data: {
      'mosqueId': event.mosqueId,
      'forceRefresh': event.forceRefresh,
    });
    
    _currentMosqueId = event.mosqueId;
    emit(PrayerTimesLoading());

    try {
      final times = await _repository.getPrayerTimes(
        event.mosqueId,
        forceRefresh: event.forceRefresh,
      );
      
      final travelTime = await _repository.getTravelTime(event.mosqueId);
      final now = DateTime.now();
      
      _startTimer();
      
      emit(_calculateState(
        times, 
        now, 
        travelTime,
        isUsingCache: times.cachedAt != null && 
          DateTime.now().difference(times.cachedAt!).inHours > 1,
      ));
      
      _logger.i('Prayer times loaded successfully');
    } on NoConnectionException catch (e) {
      _logger.w('No connection loading prayer times', error: e);
      
      // Try to load cached data
      try {
        final cached = await _repository.getPrayerTimes(
          event.mosqueId,
          forceRefresh: false,
        );
        final travelTime = await _repository.getTravelTime(event.mosqueId);
        final now = DateTime.now();
        
        _startTimer();
        
        emit(_calculateState(
          cached, 
          now, 
          travelTime, 
          isUsingCache: true,
          lastUpdated: cached.cachedAt,
          warningMessage: 'No internet connection. Showing cached data.',
        ));
      } catch (_) {
        emit(PrayerTimesError(
          message: 'No internet connection. Please check your network settings.',
          isRecoverable: true,
          errorCode: 'NO_CONNECTION',
        ));
      }
    } on RepositoryException catch (e) {
      _logger.e('Repository error loading prayer times', error: e);
      emit(PrayerTimesError(
        message: e.message,
        isRecoverable: true,
        errorCode: 'REPOSITORY_ERROR',
      ));
    } catch (e) {
      _logger.e('Unexpected error loading prayer times', error: e);
      emit(PrayerTimesError(
        message: 'An unexpected error occurred. Please try again.',
        isRecoverable: true,
        errorCode: 'UNKNOWN_ERROR',
      ));
    }
  }

  Future<void> _onRefreshPrayerTimes(
    RefreshPrayerTimes event,
    Emitter<PrayerTimesState> emit,
  ) async {
    add(LoadPrayerTimes(event.mosqueId, forceRefresh: true));
  }

  Future<void> _onUpdateCurrentTime(
    UpdateCurrentTime event,
    Emitter<PrayerTimesState> emit,
  ) async {
    if (state is PrayerTimesLoaded) {
      final current = state as PrayerTimesLoaded;
      emit(_calculateState(
        current.prayerTimes,
        event.now,
        current.travelTimeSeconds,
        isUsingCache: current.isUsingCache,
        lastUpdated: current.lastUpdated,
        warningMessage: current.warningMessage,
      ));
    }
  }

  Future<void> _onSetTravelTime(
    SetTravelTime event,
    Emitter<PrayerTimesState> emit,
  ) async {
    _logger.d('Setting travel time', data: {
      'mosqueId': event.mosqueId,
      'seconds': event.seconds,
    });
    
    try {
      await _repository.setTravelTime(event.mosqueId, event.seconds);
      
      if (state is PrayerTimesLoaded) {
        final current = state as PrayerTimesLoaded;
        emit(_calculateState(
          current.prayerTimes,
          DateTime.now(),
          event.seconds,
          isUsingCache: current.isUsingCache,
          lastUpdated: current.lastUpdated,
          warningMessage: current.warningMessage,
        ));
      }
    } catch (e) {
      _logger.e('Failed to set travel time', error: e);
      // Don't change state on error, just log it
    }
  }

  Future<void> _onLoadCachedData(
    LoadCachedData event,
    Emitter<PrayerTimesState> emit,
  ) async {
    try {
      final hasCache = await _repository.hasCachedPrayerTimes(
        event.mosqueId, 
        DateTime.now(),
      );
      
      if (hasCache) {
        final cached = await _repository.getPrayerTimes(event.mosqueId);
        final travelTime = await _repository.getTravelTime(event.mosqueId);
        final now = DateTime.now();
        
        emit(_calculateState(
          cached, 
          now, 
          travelTime, 
          isUsingCache: true,
          lastUpdated: cached.cachedAt,
        ));
      }
    } catch (e) {
      _logger.w('Failed to load cached data', error: e);
    }
  }

  PrayerTimesLoaded _calculateState(
    PrayerTimes times,
    DateTime now,
    int travelTimeSeconds, {
    bool isUsingCache = false,
    DateTime? lastUpdated,
    String? warningMessage,
  }) {
    final nextPrayer = _engine.getNextPrayer(times, now);
    
    // Get current prayer for rakah estimation
    final currentPrayer = _engine.getCurrentPrayer(times, now);
    RakahEstimate? rakahEstimate;
    if (currentPrayer != null && currentPrayer.hasIqama) {
      rakahEstimate = _engine.estimateRakah(currentPrayer, now);
    }

    // Calculate travel prediction
    TravelPrediction? travelPrediction;
    if (travelTimeSeconds > 0 && nextPrayer.prayer.hasIqama) {
      travelPrediction = _engine.calculateTravelPrediction(
        nextPrayer.prayer,
        Duration(seconds: travelTimeSeconds),
        now,
      );
    }

    return PrayerTimesLoaded(
      prayerTimes: times,
      nextPrayer: nextPrayer,
      currentRakah: rakahEstimate,
      travelPrediction: travelPrediction,
      travelTimeSeconds: travelTimeSeconds,
      isUsingCache: isUsingCache,
      lastUpdated: lastUpdated ?? times.cachedAt,
      warningMessage: warningMessage,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) {
        add(UpdateCurrentTime(DateTime.now()));
      }
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _logger.d('PrayerTimesBloc closed');
    return super.close();
  }
}
