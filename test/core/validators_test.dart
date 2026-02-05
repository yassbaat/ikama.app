import 'package:flutter_test/flutter_test.dart';
import 'package:iqamah/core/utils/validators.dart';
import 'package:iqamah/domain/entities/geo_location.dart';

void main() {
  group('Validators', () {
    group('mosqueId', () {
      test('accepts valid mosque ID', () {
        final result = Validators.mosqueId('mosque_123');
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.mosqueId(null);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('required'));
      });

      test('rejects empty string', () {
        final result = Validators.mosqueId('');
        expect(result.isValid, isFalse);
      });

      test('rejects too short', () {
        final result = Validators.mosqueId('ab');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('at least 3'));
      });
    });

    group('mosqueName', () {
      test('accepts valid name', () {
        final result = Validators.mosqueName('Central Mosque');
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.mosqueName(null);
        expect(result.isValid, isFalse);
      });

      test('rejects too short', () {
        final result = Validators.mosqueName('A');
        expect(result.isValid, isFalse);
      });

      test('rejects too long', () {
        final result = Validators.mosqueName('A' * 201);
        expect(result.isValid, isFalse);
      });
    });

    group('searchQuery', () {
      test('accepts valid query', () {
        final result = Validators.searchQuery('central mosque');
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.searchQuery(null);
        expect(result.isValid, isFalse);
      });

      test('rejects too short', () {
        final result = Validators.searchQuery('a');
        expect(result.isValid, isFalse);
      });

      test('rejects SQL injection attempt', () {
        final result = Validators.searchQuery('mosque; DROP TABLE;');
        expect(result.isValid, isFalse);
      });

      test('rejects HTML tags', () {
        final result = Validators.searchQuery('<script>alert(1)</script>');
        expect(result.isValid, isFalse);
      });
    });

    group('url', () {
      test('accepts valid HTTPS URL', () {
        final result = Validators.url('https://example.com');
        expect(result.isValid, isTrue);
      });

      test('accepts valid HTTP URL', () {
        final result = Validators.url('http://example.com');
        expect(result.isValid, isTrue);
      });

      test('accepts URL with path', () {
        final result = Validators.url('https://api.example.com/v1/mosques');
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.url(null);
        expect(result.isValid, isFalse);
      });

      test('rejects empty string', () {
        final result = Validators.url('');
        expect(result.isValid, isFalse);
      });

      test('rejects invalid URL', () {
        final result = Validators.url('not a url');
        expect(result.isValid, isFalse);
      });

      test('rejects FTP protocol', () {
        final result = Validators.url('ftp://example.com');
        expect(result.isValid, isFalse);
      });
    });

    group('coordinates', () {
      test('accepts valid coordinates', () {
        final result = Validators.coordinates(40.7128, -74.0060);
        expect(result.isValid, isTrue);
      });

      test('accepts edge values', () {
        final result = Validators.coordinates(90, 180);
        expect(result.isValid, isTrue);
      });

      test('accepts negative edge values', () {
        final result = Validators.coordinates(-90, -180);
        expect(result.isValid, isTrue);
      });

      test('rejects null latitude', () {
        final result = Validators.coordinates(null, 0);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Latitude is required'));
      });

      test('rejects null longitude', () {
        final result = Validators.coordinates(0, null);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Longitude is required'));
      });

      test('rejects out of range latitude', () {
        final result = Validators.coordinates(91, 0);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Latitude must be between'));
      });

      test('rejects out of range longitude', () {
        final result = Validators.coordinates(0, 181);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Longitude must be between'));
      });
    });

    group('geoLocation', () {
      test('accepts valid location', () {
        final location = GeoLocation(latitude: 40.7128, longitude: -74.0060);
        final result = Validators.geoLocation(location);
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.geoLocation(null);
        expect(result.isValid, isFalse);
      });
    });

    group('travelTime', () {
      test('accepts valid travel time', () {
        final result = Validators.travelTime(1800); // 30 minutes
        expect(result.isValid, isTrue);
      });

      test('accepts zero', () {
        final result = Validators.travelTime(0);
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.travelTime(null);
        expect(result.isValid, isFalse);
      });

      test('rejects negative', () {
        final result = Validators.travelTime(-100);
        expect(result.isValid, isFalse);
      });

      test('rejects too large', () {
        final result = Validators.travelTime(90000); // 25 hours
        expect(result.isValid, isFalse);
      });
    });

    group('rakahDuration', () {
      test('accepts valid duration', () {
        final result = Validators.rakahDuration(144); // 2.4 minutes
        expect(result.isValid, isTrue);
      });

      test('rejects too short', () {
        final result = Validators.rakahDuration(10);
        expect(result.isValid, isFalse);
      });

      test('rejects too long', () {
        final result = Validators.rakahDuration(700);
        expect(result.isValid, isFalse);
      });
    });

    group('apiToken', () {
      test('accepts valid token', () {
        final result = Validators.apiToken('valid_token_12345');
        expect(result.isValid, isTrue);
      });

      test('rejects null when required', () {
        final result = Validators.apiToken(null, required: true);
        expect(result.isValid, isFalse);
      });

      test('accepts null when not required', () {
        final result = Validators.apiToken(null, required: false);
        expect(result.isValid, isTrue);
      });

      test('rejects too short', () {
        final result = Validators.apiToken('short');
        expect(result.isValid, isFalse);
      });
    });

    group('email', () {
      test('accepts valid email', () {
        final result = Validators.email('test@example.com');
        expect(result.isValid, isTrue);
      });

      test('accepts email with dots', () {
        final result = Validators.email('user.name@example.co.uk');
        expect(result.isValid, isTrue);
      });

      test('accepts email with plus', () {
        final result = Validators.email('user+tag@example.com');
        expect(result.isValid, isTrue);
      });

      test('rejects null', () {
        final result = Validators.email(null);
        expect(result.isValid, isFalse);
      });

      test('rejects empty', () {
        final result = Validators.email('');
        expect(result.isValid, isFalse);
      });

      test('rejects missing @', () {
        final result = Validators.email('testexample.com');
        expect(result.isValid, isFalse);
      });

      test('rejects missing domain', () {
        final result = Validators.email('test@');
        expect(result.isValid, isFalse);
      });

      test('rejects missing local part', () {
        final result = Validators.email('@example.com');
        expect(result.isValid, isFalse);
      });
    });
  });

  group('Sanitizers', () {
    group('string', () {
      test('trims whitespace', () {
        final result = Sanitizers.string('  hello  ');
        expect(result, equals('hello'));
      });

      test('removes control characters', () {
        final result = Sanitizers.string('hello\x00world');
        expect(result, equals('helloworld'));
      });

      test('handles null', () {
        final result = Sanitizers.string(null);
        expect(result, equals(''));
      });

      test('enforces max length', () {
        final longString = 'a' * 1000;
        final result = Sanitizers.string(longString, maxLength: 100);
        expect(result.length, equals(100));
      });
    });

    group('url', () {
      test('trims whitespace from valid URL', () {
        final result = Sanitizers.url('  https://example.com  ');
        expect(result, equals('https://example.com'));
      });

      test('returns null for invalid URL', () {
        final result = Sanitizers.url('not a url');
        expect(result, isNull);
      });

      test('handles null', () {
        final result = Sanitizers.url(null);
        expect(result, isNull);
      });
    });

    group('doubleInRange', () {
      test('returns value within range', () {
        final result = Sanitizers.doubleInRange(50.5, 0, 100);
        expect(result, equals(50.5));
      });

      test('clamps to min', () {
        final result = Sanitizers.doubleInRange(-10, 0, 100);
        expect(result, equals(0));
      });

      test('clamps to max', () {
        final result = Sanitizers.doubleInRange(150, 0, 100);
        expect(result, equals(100));
      });

      test('parses string', () {
        final result = Sanitizers.doubleInRange('50.5', 0, 100);
        expect(result, equals(50.5));
      });

      test('returns null for invalid', () {
        final result = Sanitizers.doubleInRange('invalid', 0, 100);
        expect(result, isNull);
      });
    });

    group('intInRange', () {
      test('returns value within range', () {
        final result = Sanitizers.intInRange(50, 0, 100);
        expect(result, equals(50));
      });

      test('clamps to min', () {
        final result = Sanitizers.intInRange(-10, 0, 100);
        expect(result, equals(0));
      });

      test('clamps to max', () {
        final result = Sanitizers.intInRange(150, 0, 100);
        expect(result, equals(100));
      });

      test('parses string', () {
        final result = Sanitizers.intInRange('50', 0, 100);
        expect(result, equals(50));
      });

      test('returns null for invalid', () {
        final result = Sanitizers.intInRange('invalid', 0, 100);
        expect(result, isNull);
      });
    });
  });
}
