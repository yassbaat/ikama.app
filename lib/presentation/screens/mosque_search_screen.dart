import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/mosque_bloc.dart';
import '../blocs/prayer_times_bloc.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/geo_location.dart';

class MosqueSearchScreen extends StatefulWidget {
  const MosqueSearchScreen({super.key});

  @override
  State<MosqueSearchScreen> createState() => _MosqueSearchScreenState();
}

class _MosqueSearchScreenState extends State<MosqueSearchScreen> {
  final _searchController = TextEditingController();
  final _debouncer = _Debouncer(milliseconds: 500);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search mosques...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<MosqueBloc>().add(LoadMosques());
                  },
                )
              : null,
          ),
          onChanged: (value) {
            _debouncer.run(() {
              context.read<MosqueBloc>().add(SearchMosques(value));
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _searchNearby,
            tooltip: 'Nearby mosques',
          ),
        ],
      ),
      body: BlocBuilder<MosqueBloc, MosqueState>(
        builder: (context, state) {
          if (state is MosqueLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MosqueSearchResults) {
            if (state.results.isEmpty) {
              return _buildEmptyState('No mosques found for "${state.query}"');
            }
            return _buildMosqueList(state.results, isSearchResult: true);
          }

          if (state is NearbyMosquesLoaded) {
            if (state.mosques.isEmpty) {
              return _buildEmptyState('No mosques found nearby');
            }
            return _buildMosqueList(state.mosques, isNearby: true);
          }

          if (state is MosquesLoaded) {
            if (state.mosques.isEmpty) {
              return _buildInitialState();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.activeMosque != null) ...[
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Active Mosque',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildMosqueTile(state.activeMosque!, isActive: true),
                  const Divider(),
                ],
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Favorites',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.mosques.length,
                    itemBuilder: (context, index) => _buildMosqueTile(
                      state.mosques[index],
                      isFavorite: true,
                    ),
                  ),
                ),
              ],
            );
          }

          if (state is MosqueError) {
            return _buildErrorState(state.message);
          }

          return _buildInitialState();
        },
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Search for Mosques',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter a city or mosque name\nor use nearby search',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _searchNearby,
            icon: const Icon(Icons.my_location),
            label: const Text('Find Nearby Mosques'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mosque_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildMosqueList(List<Mosque> mosques, {bool isSearchResult = false, bool isNearby = false}) {
    return ListView.builder(
      itemCount: mosques.length,
      itemBuilder: (context, index) {
        final mosque = mosques[index];
        return _buildMosqueTile(
          mosque,
          subtitle: isNearby && mosque.latitude != null
            ? '${mosque.address ?? ''} • ${_formatDistance(mosque)}'
            : mosque.address,
        );
      },
    );
  }

  Widget _buildMosqueTile(
    Mosque mosque, {
    bool isActive = false,
    bool isFavorite = false,
    String? subtitle,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive 
          ? Theme.of(context).colorScheme.primary 
          : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.mosque,
          color: isActive 
            ? Theme.of(context).colorScheme.onPrimary 
            : Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(mosque.name),
      subtitle: subtitle != null 
        ? Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis)
        : (mosque.address != null ? Text(mosque.address!) : null),
      trailing: isActive
        ? const Icon(Icons.check_circle, color: Colors.green)
        : isFavorite
          ? const Icon(Icons.favorite, color: Colors.red)
          : null,
      onTap: () => _selectMosque(mosque),
    );
  }

  String _formatDistance(Mosque mosque) {
    // Placeholder - in real implementation calculate from user location
    return 'nearby';
  }

  void _selectMosque(Mosque mosque) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                mosque.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (mosque.address != null) ...[
                const SizedBox(height: 8),
                Text(mosque.address!),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<MosqueBloc>().add(SetActiveMosque(mosque.id));
                  context.read<PrayerTimesBloc>().add(LoadPrayerTimes(mosque.id));
                  Navigator.pop(context); // Close bottom sheet
                  Navigator.pop(context); // Close search screen
                },
                icon: const Icon(Icons.check),
                label: const Text('Set as Active Mosque'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<MosqueBloc>().add(ToggleFavorite(mosque.id));
                  Navigator.pop(context);
                },
                icon: Icon(mosque.isFavorite ? Icons.favorite : Icons.favorite_border),
                label: Text(mosque.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchNearby() async {
    // In production, use geolocator to get actual location
    // For now, use a placeholder
    final location = GeoLocation(
      latitude: 48.8566, // Paris
      longitude: 2.3522,
    );
    context.read<MosqueBloc>().add(LoadNearbyMosques(location));
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
