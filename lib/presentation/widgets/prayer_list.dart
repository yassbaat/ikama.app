import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/prayer_times.dart';

class PrayerList extends StatelessWidget {
  final PrayerTimes prayerTimes;

  const PrayerList({super.key, required this.prayerTimes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prayers = prayerTimes.allPrayers;
    final now = DateTime.now();

    // Find current prayer index
    int? currentIndex;
    for (int i = 0; i < prayers.length; i++) {
      if (now.isAfter(prayers[i].adhan) &&
          (i == prayers.length - 1 || now.isBefore(prayers[i + 1].adhan))) {
        currentIndex = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Prayers',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prayers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final prayer = prayers[index];
              final isCurrent = index == currentIndex;
              final isPast = now.isAfter(prayer.adhan) && !isCurrent;

              return _PrayerListTile(
                prayer: prayer,
                isCurrent: isCurrent,
                isPast: isPast,
              );
            },
          ),
        ),
        if (prayerTimes.jumuah != null) ...[
          const SizedBox(height: 16),
          Text(
            'Friday Prayer',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: _PrayerListTile(
              prayer: prayerTimes.jumuah!,
              isCurrent: false,
              isPast: false,
              isJumuah: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _PrayerListTile extends StatelessWidget {
  final Prayer prayer;
  final bool isCurrent;
  final bool isPast;
  final bool isJumuah;

  const _PrayerListTile({
    required this.prayer,
    required this.isCurrent,
    required this.isPast,
    this.isJumuah = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: isCurrent
          ? BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            )
          : null,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCurrent
                ? theme.colorScheme.primary
                : isPast
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surfaceContainerLowest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              _getIconData(),
              color: isCurrent
                  ? theme.colorScheme.onPrimary
                  : isPast
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : theme.colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          prayer.name + (isJumuah ? ' (Friday)' : ''),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isPast
                ? theme.colorScheme.onSurface.withOpacity(0.5)
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Row(
          children: [
            if (isCurrent)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'CURRENT',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              'Adhan: ${_formatTime(prayer.adhan)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isPast
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              prayer.iqama != null ? _formatTime(prayer.iqama!) : '--:--',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPast
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : theme.colorScheme.primary,
              ),
            ),
            Text(
              'Iqama',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData() {
    switch (prayer.name) {
      case 'Fajr':
        return Icons.wb_twilight;
      case 'Dhuhr':
        return Icons.wb_sunny;
      case 'Asr':
        return Icons.wb_cloudy;
      case 'Maghrib':
        return Icons.wb_twilight;
      case 'Isha':
        return Icons.nights_stay;
      case 'Jumuah':
        return Icons.mosque;
      default:
        return Icons.access_time;
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat.Hm().format(time);
  }
}
