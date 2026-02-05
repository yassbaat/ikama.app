import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/prayer_times_bloc.dart';
import '../blocs/mosque_bloc.dart';
import '../widgets/next_prayer_card.dart';
import '../widgets/prayer_list.dart';
import '../widgets/live_rakah_card.dart';
import '../widgets/travel_time_card.dart';
import 'mosque_search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MosqueBloc>().add(LoadMosques());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<MosqueBloc, MosqueState>(
        builder: (context, mosqueState) {
          return BlocBuilder<PrayerTimesBloc, PrayerTimesState>(
            builder: (context, prayerState) {
              return CustomScrollView(
                slivers: [
                  _buildAppBar(context, mosqueState),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildContent(context, mosqueState, prayerState),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMosqueSelector(context),
        icon: const Icon(Icons.mosque),
        label: const Text('Change Mosque'),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, MosqueState state) {
    String title = 'Iqamah';
    String? subtitle;

    if (state is MosquesLoaded && state.activeMosque != null) {
      subtitle = state.activeMosque!.name;
    }

    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20)),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            final mosqueState = context.read<MosqueBloc>().state;
            if (mosqueState is MosquesLoaded && mosqueState.activeMosque != null) {
              context.read<PrayerTimesBloc>().add(
                RefreshPrayerTimes(mosqueState.activeMosque!.id),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, MosqueState mosqueState, PrayerTimesState prayerState) {
    if (mosqueState is MosqueLoading || prayerState is PrayerTimesLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (mosqueState is MosquesLoaded && mosqueState.activeMosque == null) {
      return _buildNoMosqueSelected(context);
    }

    if (prayerState is PrayerTimesError) {
      return _buildErrorState(context, prayerState);
    }

    if (prayerState is PrayerTimesLoaded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (prayerState.isUsingCache)
            _buildCacheWarning(prayerState.lastUpdated),
          
          NextPrayerCard(
            nextPrayer: prayerState.nextPrayer,
            onSetTravelTime: (seconds) {
              context.read<PrayerTimesBloc>().add(
                SetTravelTime(prayerState.prayerTimes.mosqueId!, seconds),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          if (prayerState.currentRakah != null && 
              prayerState.currentRakah!.status != 'not_available')
            LiveRakahCard(estimate: prayerState.currentRakah!),
          
          if (prayerState.travelPrediction != null)
            TravelTimeCard(prediction: prayerState.travelPrediction!),
          
          const SizedBox(height: 16),
          
          PrayerList(prayerTimes: prayerState.prayerTimes),
          
          const SizedBox(height: 80), // Space for FAB
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNoMosqueSelected(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mosque_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Mosque Selected',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a mosque to see prayer times',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showMosqueSelector(context),
            icon: const Icon(Icons.search),
            label: const Text('Find a Mosque'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, PrayerTimesError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Unable to Load Data',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final mosqueState = context.read<MosqueBloc>().state;
              if (mosqueState is MosquesLoaded && mosqueState.activeMosque != null) {
                context.read<PrayerTimesBloc>().add(
                  RefreshPrayerTimes(mosqueState.activeMosque!.id),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheWarning(DateTime? lastUpdated) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Using cached data',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                if (lastUpdated != null)
                  Text(
                    'Last updated: ${_formatTime(lastUpdated)}',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showMosqueSelector(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MosqueSearchScreen()),
    );
  }
}
