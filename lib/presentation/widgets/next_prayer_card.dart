import 'package:flutter/material.dart';
import '../../domain/services/prayer_engine.dart';

class NextPrayerCard extends StatelessWidget {
  final NextPrayerResult nextPrayer;
  final Function(int seconds)? onSetTravelTime;

  const NextPrayerCard({
    super.key,
    required this.nextPrayer,
    this.onSetTravelTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.primary,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Prayer',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextPrayer.prayer.name,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (nextPrayer.isTomorrow)
                        Text(
                          'Tomorrow',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  _buildCountdown(theme),
                ],
              ),
              const Divider(height: 32, color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeInfo(
                    'Adhan',
                    _formatTime(nextPrayer.prayer.adhan),
                    theme,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white24,
                  ),
                  _buildTimeInfo(
                    'Iqama',
                    nextPrayer.prayer.iqama != null
                      ? _formatTime(nextPrayer.prayer.iqama!)
                      : '--:--',
                    theme,
                    isHighlighted: true,
                  ),
                ],
              ),
              if (nextPrayer.prayer.iqama != null) ...[
                const SizedBox(height: 16),
                _buildTimeUntilIqama(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown(ThemeData theme) {
    final duration = nextPrayer.timeUntilIqama ?? nextPrayer.timeUntilAdhan;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            hours > 0 
              ? '${hours}h ${minutes}m'
              : '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'until ${nextPrayer.prayer.iqama != null ? 'iqama' : 'adhan'}',
            style: TextStyle(
              color: theme.colorScheme.onPrimary.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, ThemeData theme, {bool isHighlighted = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onPrimary.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: isHighlighted ? 20 : 18,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUntilIqama(ThemeData theme) {
    final timeUntil = nextPrayer.timeUntilIqama;
    if (timeUntil == null) return const SizedBox.shrink();

    final isUrgent = timeUntil.inMinutes < 15;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUrgent 
          ? Colors.orange.withOpacity(0.3) 
          : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUrgent ? Icons.notification_important : Icons.access_time,
            color: theme.colorScheme.onPrimary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '${timeUntil.inMinutes} minutes until iqama',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
