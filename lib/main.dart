import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/utils/connectivity_manager.dart';
import 'core/utils/logger.dart';
import 'data/providers/community_wrapper_provider.dart';
import 'data/providers/official_api_provider.dart';
import 'data/providers/scraping_provider.dart';
import 'data/providers/fallback_provider.dart';
import 'data/repositories/robust_mosque_repository.dart';
import 'data/local/preferences_service.dart';
import 'platform/background/background_service.dart';
import 'platform/notifications/notification_service.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/blocs/prayer_times_bloc.dart';
import 'presentation/blocs/mosque_bloc.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger first
  final logger = AppLogger();
  logger.initialize(config: kDebugMode 
    ? LoggerConfig.development 
    : LoggerConfig.production);
  
  logger.i('Starting Iqamah App');
  
  try {
    // Initialize core services
    final prefs = PreferencesService();
    await prefs.initialize();
    logger.d('Preferences initialized');
    
    // Initialize connectivity manager
    final connectivity = ConnectivityManager();
    await connectivity.initialize();
    logger.d('Connectivity manager initialized');
    
    // Initialize background service
    final backgroundService = BackgroundService();
    await backgroundService.initialize();
    logger.d('Background service initialized');
    
    // Initialize notifications
    final notifications = NotificationService();
    await notifications.initialize();
    logger.d('Notification service initialized');
    
    runApp(IqamahApp(
      prefs: prefs,
      connectivity: connectivity,
      backgroundService: backgroundService,
      notifications: notifications,
    ));
    
    logger.i('App started successfully');
  } catch (e, stackTrace) {
    logger.f('Failed to start app', error: e, stackTrace: stackTrace);
    // In a real app, you might want to show an error screen
    rethrow;
  }
}

class IqamahApp extends StatefulWidget {
  final PreferencesService prefs;
  final ConnectivityManager connectivity;
  final BackgroundService backgroundService;
  final NotificationService notifications;

  const IqamahApp({
    super.key,
    required this.prefs,
    required this.connectivity,
    required this.backgroundService,
    required this.notifications,
  });

  @override
  State<IqamahApp> createState() => _IqamahAppState();
}

class _IqamahAppState extends State<IqamahApp> with WidgetsBindingObserver {
  late final RobustMosqueRepository _repository;
  late final AppLogger _logger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logger = AppLogger();
    _initializeRepository();
  }

  void _initializeRepository() {
    // Build provider chain with fallback
    final activeProviderId = widget.prefs.getActiveProvider() ?? 'community_wrapper';
    
    final fallbackProvider = FallbackProviderBuilder()
      .addIf(CommunityWrapperProvider(), activeProviderId == 'community_wrapper')
      .addIf(OfficialApiProvider(), activeProviderId == 'official_api')
      .add(ScrapingProvider()) // Always add scraping as last resort
      .build();

    // Initialize the fallback provider with stored configs
    final configs = <String, dynamic>{};
    for (final providerId in ['community_wrapper', 'official_api', 'scraping']) {
      final config = widget.prefs.getProviderConfig(providerId);
      if (config != null) {
        configs[providerId] = config;
      }
    }
    
    fallbackProvider.initialize(configs);

    _repository = RobustMosqueRepository(
      provider: fallbackProvider,
      connectivity: widget.connectivity,
    );

    _logger.i('Repository initialized with provider: $activeProviderId');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _logger.d('App resumed');
        // Refresh data when app comes to foreground
        _repository.clearOldCache();
        break;
      case AppLifecycleState.paused:
        _logger.d('App paused');
        break;
      case AppLifecycleState.detached:
        _logger.d('App detached');
        break;
      case AppLifecycleState.hidden:
        _logger.d('App hidden');
        break;
      case AppLifecycleState.inactive:
        _logger.d('App inactive');
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repository.clearOldCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _repository),
        RepositoryProvider.value(value: widget.prefs),
        RepositoryProvider.value(value: widget.notifications),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => MosqueBloc(repository: _repository),
          ),
          BlocProvider(
            create: (context) => PrayerTimesBloc(
              repository: _repository,
              preferences: widget.prefs,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Iqamah',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
          builder: (context, child) {
            // Add error boundary
            return ErrorBoundary(
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}

/// Error boundary widget to catch and display errors gracefully
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  ErrorDetails? _error;

  @override
  void initState() {
    super.initState();
    // Set up error handling
    FlutterError.onError = (details) {
      AppLogger().e(
        'Flutter error: ${details.exception}',
        stackTrace: details.stack,
      );
      
      if (mounted) {
        setState(() {
          _error = ErrorDetails(
            exception: details.exception,
            stack: details.stack,
          );
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorScreen();
    }
    
    return widget.child;
  }

  Widget _buildErrorScreen() {
    return Material(
      child: Container(
        color: Colors.red.shade50,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please restart the app. If the problem persists, contact support.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorDetails {
  final Object exception;
  final StackTrace? stack;

  ErrorDetails({required this.exception, this.stack});
}

/// Debug flag - would be false in production
const bool kDebugMode = bool.fromEnvironment('dart.vm.product') == false;
