import 'package:flutter_test/flutter_test.dart';
import 'package:iqamah/data/providers/official_api_provider.dart';
import 'package:iqamah/data/providers/community_wrapper_provider.dart';
import 'package:iqamah/data/providers/scraping_provider.dart';
import 'package:iqamah/data/providers/prayer_data_provider.dart';

void main() {
  group('PrayerDataProvider Implementations', () {
    group('OfficialApiProvider', () {
      late OfficialApiProvider provider;

      setUp(() {
        provider = OfficialApiProvider();
      });

      test('has correct ID and name', () {
        expect(provider.id, 'official_api');
        expect(provider.name, 'Official Mawaqit API');
      });

      test('requires baseUrl and apiToken in config', () {
        final schema = provider.configSchema;
        
        final baseUrlField = schema.firstWhere((f) => f.key == 'baseUrl');
        final tokenField = schema.firstWhere((f) => f.key == 'apiToken');
        
        expect(baseUrlField.required, true);
        expect(tokenField.required, true);
      });

      test('throws exception when initialized without required config', () async {
        expect(
          () => provider.initialize({}),
          throwsA(isA<ProviderException>()),
        );
      });
    });

    group('CommunityWrapperProvider', () {
      late CommunityWrapperProvider provider;

      setUp(() {
        provider = CommunityWrapperProvider();
      });

      test('has correct ID and name', () {
        expect(provider.id, 'community_wrapper');
        expect(provider.name, 'Community API Wrapper');
      });

      test('requires only baseUrl in config', () {
        final schema = provider.configSchema;
        
        final baseUrlField = schema.firstWhere((f) => f.key == 'baseUrl');
        final apiKeyField = schema.firstWhere((f) => f.key == 'apiKey');
        
        expect(baseUrlField.required, true);
        expect(apiKeyField.required, false);
      });
    });

    group('ScrapingProvider', () {
      late ScrapingProvider provider;

      setUp(() {
        provider = ScrapingProvider();
      });

      test('has correct ID and name', () {
        expect(provider.id, 'scraping');
        expect(provider.name, 'Web Scraping (Fallback)');
      });

      test('has optional baseUrl with default', () {
        final schema = provider.configSchema;
        
        final baseUrlField = schema.firstWhere((f) => f.key == 'baseUrl');
        
        expect(baseUrlField.required, false);
        expect(baseUrlField.defaultValue, 'https://mawaqit.net');
      });
    });
  });

  group('Provider ConfigField', () {
    test('serializes to JSON correctly', () {
      const field = ConfigField(
        key: 'testKey',
        label: 'Test Label',
        type: ConfigFieldType.string,
        required: true,
        description: 'A test field',
        defaultValue: 'default',
      );

      final json = field.toJson();

      expect(json['key'], 'testKey');
      expect(json['label'], 'Test Label');
      expect(json['type'], 'string');
      expect(json['required'], true);
      expect(json['description'], 'A test field');
      expect(json['defaultValue'], 'default');
    });
  });
}
