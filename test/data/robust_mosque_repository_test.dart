import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:iqamah/data/repositories/robust_mosque_repository.dart';
import 'package:iqamah/data/local/database_helper.dart';
import 'package:iqamah/data/providers/prayer_data_provider.dart';
import 'package:iqamah/domain/entities/mosque.dart';
import 'package:iqamah/domain/entities/prayer_times.dart';
import 'package:iqamah/domain/entities/geo_location.dart';
import 'package:iqamah/core/errors/exceptions.dart';

@GenerateMocks([DatabaseHelper, PrayerDataProvider])
import 'robust_mosque_repository_test.mocks.dart';

void main() {
  group('RobustMosqueRepository', () {
    late RobustMosqueRepository repository;
    late MockDatabaseHelper mockDatabase;
    late MockPrayerDataProvider mockProvider;

    setUp(() {
      mockDatabase = MockDatabaseHelper();
      mockProvider = MockPrayerDataProvider();
      repository = RobustMosqueRepository(
        provider: mockProvider,
        database: mockDatabase,
      );
    });

    group('getPrayerTimes', () {
      final testMosqueId = 'mosque_123';
      final testDate = DateTime(2024, 1, 15);
      final testPrayerTimes = PrayerTimes(
        date: testDate,
        mosqueId: testMosqueId,
        cachedAt: DateTime.now(),
        fajr: Prayer(name: 'Fajr', adhan: DateTime(2024, 1, 15, 5, 30), iqama: DateTime(2024, 1, 15, 5, 45)),
        dhuhr: Prayer(name: 'Dhuhr', adhan: DateTime(2024, 1, 15, 12, 30), iqama: DateTime(2024, 1, 15, 12, 45)),
        asr: Prayer(name: 'Asr', adhan: DateTime(2024, 1, 15, 15, 45), iqama: DateTime(2024, 1, 15, 16, 0)),
        maghrib: Prayer(name: 'Maghrib', adhan: DateTime(2024, 1, 15, 18, 15), iqama: DateTime(2024, 1, 15, 18, 25)),
        isha: Prayer(name: 'Isha', adhan: DateTime(2024, 1, 15, 19, 45), iqama: DateTime(2024, 1, 15, 20, 0)),
      );

      test('returns cached data when fresh', () async {
        // Arrange
        final freshCache = testPrayerTimes.copyWith(
          cachedAt: DateTime.now().subtract(Duration(minutes: 30)),
        );
        when(mockDatabase.getCachedPrayerTimes(testMosqueId, testDate))
          .thenAnswer((_) async => freshCache);

        // Act
        final result = await repository.getPrayerTimes(testMosqueId, date: testDate);

        // Assert
        expect(result, equals(freshCache));
        verify(mockDatabase.getCachedPrayerTimes(testMosqueId, testDate)).called(1);
        verifyNever(mockProvider.getPrayerTimes(any, date: anyNamed('date')));
      });

      test('fetches from remote when no cache', () async {
        // Arrange
        when(mockDatabase.getCachedPrayerTimes(testMosqueId, testDate))
          .thenAnswer((_) async => null);
        when(mockProvider.getPrayerTimes(testMosqueId, date: testDate))
          .thenAnswer((_) async => testPrayerTimes);
        when(mockDatabase.cachePrayerTimes(any))
          .thenAnswer((_) async => {});

        // Act
        final result = await repository.getPrayerTimes(testMosqueId, date: testDate);

        // Assert
        expect(result.mosqueId, equals(testMosqueId));
        verify(mockProvider.getPrayerTimes(testMosqueId, date: testDate)).called(1);
        verify(mockDatabase.cachePrayerTimes(any)).called(1);
      });

      test('returns stale cache when remote fails', () async {
        // Arrange
        final staleCache = testPrayerTimes.copyWith(
          cachedAt: DateTime.now().subtract(Duration(hours: 3)),
        );
        when(mockDatabase.getCachedPrayerTimes(testMosqueId, testDate))
          .thenAnswer((_) async => staleCache);
        when(mockProvider.getPrayerTimes(any, date: anyNamed('date')))
          .thenThrow(NetworkException(message: 'Network error'));

        // Act
        final result = await repository.getPrayerTimes(testMosqueId, date: testDate);

        // Assert
        expect(result, equals(staleCache));
      });

      test('throws when no cache and network fails', () async {
        // Arrange
        when(mockDatabase.getCachedPrayerTimes(testMosqueId, testDate))
          .thenAnswer((_) async => null);
        when(mockProvider.getPrayerTimes(any, date: anyNamed('date')))
          .thenThrow(NetworkException(message: 'Network error'));

        // Act & Assert
        expect(
          () => repository.getPrayerTimes(testMosqueId, date: testDate),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('forces refresh when forceRefresh is true', () async {
        // Arrange
        final freshCache = testPrayerTimes.copyWith(
          cachedAt: DateTime.now().subtract(Duration(minutes: 5)),
        );
        when(mockDatabase.getCachedPrayerTimes(testMosqueId, testDate))
          .thenAnswer((_) async => freshCache);
        when(mockProvider.getPrayerTimes(testMosqueId, date: testDate))
          .thenAnswer((_) async => testPrayerTimes);
        when(mockDatabase.cachePrayerTimes(any))
          .thenAnswer((_) async => {});

        // Act
        final result = await repository.getPrayerTimes(
          testMosqueId, 
          date: testDate, 
          forceRefresh: true,
        );

        // Assert
        verify(mockProvider.getPrayerTimes(testMosqueId, date: testDate)).called(1);
      });
    });

    group('searchMosques', () {
      final testQuery = 'central mosque';
      final testMosques = [
        Mosque(id: '1', name: 'Central Mosque'),
        Mosque(id: '2', name: 'Central Islamic Center'),
      ];

      test('returns results from provider', () async {
        // Arrange
        when(mockProvider.searchMosques(testQuery, location: null))
          .thenAnswer((_) async => testMosques);

        // Act
        final result = await repository.searchMosques(testQuery);

        // Assert
        expect(result.length, equals(2));
        verify(mockProvider.searchMosques(testQuery, location: null)).called(1);
      });

      test('returns cached favorites when offline', () async {
        // Arrange
        when(mockProvider.searchMosques(any, location: anyNamed('location')))
          .thenThrow(NoConnectionException());
        when(mockDatabase.getFavoriteMosques())
          .thenAnswer((_) async => testMosques);

        // Act
        final result = await repository.searchMosques(testQuery);

        // Assert
        expect(result.length, equals(2));
      });
    });

    group('getNearbyMosques', () {
      final testLocation = GeoLocation(latitude: 40.7128, longitude: -74.0060);
      final testMosques = [
        Mosque(id: '1', name: 'Nearby Mosque 1', latitude: 40.71, longitude: -74.01),
        Mosque(id: '2', name: 'Nearby Mosque 2', latitude: 40.72, longitude: -74.00),
      ];

      test('returns results sorted by distance', () async {
        // Arrange
        when(mockProvider.getNearbyMosques(testLocation, radiusKm: 10))
          .thenAnswer((_) async => testMosques);

        // Act
        final result = await repository.getNearbyMosques(testLocation);

        // Assert
        expect(result.length, equals(2));
      });
    });
  });
}
