import 'package:flutter/material.dart';
import '../../domain/services/prayer_engine.dart';

class TravelTimeCard extends StatelessWidget {
  final TravelPrediction prediction;

  const TravelTimeCard({super.key, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Travel Time',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (prediction.shouldLeaveNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prediction.isLate 
                          ? Colors.red.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      prediction.isLate ? 'LEAVE NOW!' : 'Leave Now',
                      style: TextStyle(
                        color: prediction.isLate ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildContent(theme),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Estimated arrival rak\'ah—still go; you may catch it.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTimeBlock(
                'Leave By',
                _formatTime(prediction.recommendedLeaveTime),
                prediction.shouldLeaveNow 
                  ? (prediction.isLate ? Colors.red : Colors.orange)
                  : theme.colorScheme.primary,
                theme,
              ),
            ),
            Icon(Icons.arrow_forward, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            Expanded(
              child: _buildTimeBlock(
                'Arrival',
                _formatTime(prediction.arrivalTime),
                theme.colorScheme.secondary,
                theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getArrivalIcon(),
                color: _getArrivalColor(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getArrivalText(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (prediction.timeUntilLeave != null)
                      Text(
                        'Leave in ${_formatDuration(prediction.timeUntilLeave!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBlock(String label, String time, Color color, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getArrivalText() {
    switch (prediction.arrivalStatus) {
      case 'before_start':
        return 'You will arrive before prayer starts ✓';
      case 'in_progress':
        if (prediction.arrivalRakah != null) {
          return 'Estimated arrival at Rak\'ah ${prediction.arrivalRakah}';
        }
        return 'Prayer in progress';
      case 'after_estimated_end':
        return 'May arrive after estimated end';
      case 'iqama_unavailable':
        return 'Iqama time unavailable';
      default:
        return 'Arrival status unknown';
    }
  }

  IconData _getArrivalIcon() {
    switch (prediction.arrivalStatus) {
      case 'before_start':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.timelapse;
      case 'after_estimated_end':
        return Icons.warning;
      case 'iqama_unavailable':
        return Icons.help_outline;
      default:
        return Icons.schedule;
    }
  }

  Color _getArrivalColor() {
    switch (prediction.arrivalStatus) {
      case 'before_start':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'after_estimated_end':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }
}
