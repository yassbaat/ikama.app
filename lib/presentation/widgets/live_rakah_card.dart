import 'package:flutter/material.dart';
import '../../domain/services/prayer_engine.dart';

class LiveRakahCard extends StatelessWidget {
  final RakahEstimate estimate;

  const LiveRakahCard({super.key, required this.estimate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE (estimated)',
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildStatusIcon(),
              ],
            ),
            const SizedBox(height: 16),
            _buildContent(theme),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Estimate—still go; you may catch it.',
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
    switch (estimate.status) {
      case 'not_started':
        return _buildNotStarted(theme);
      case 'in_progress':
        return _buildInProgress(theme);
      case 'likely_finished':
        return _buildFinished(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNotStarted(ThemeData theme) {
    final remaining = estimate.remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prayer has not started yet',
          style: theme.textTheme.titleMedium,
        ),
        if (remaining != null) ...[
          const SizedBox(height: 8),
          Text(
            'Starting in ${_formatDuration(remaining)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInProgress(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rak\'ah ${estimate.currentRakah} / ${estimate.totalRakah}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (estimate.elapsed != null)
                    Text(
                      'Started ${_formatDuration(estimate.elapsed!)} ago (est.)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (estimate.remaining != null && estimate.remaining!.inSeconds > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '~${_formatDuration(estimate.remaining!)} left',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: estimate.progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinished(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Likely finished (estimated)',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        if (estimate.elapsed != null)
          Text(
            'Ended ${_formatDuration(estimate.elapsed!)} ago (est.)',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    switch (estimate.status) {
      case 'not_started':
        icon = Icons.schedule;
        break;
      case 'in_progress':
        icon = Icons.play_circle_outline;
        break;
      case 'likely_finished':
        icon = Icons.check_circle_outline;
        break;
      default:
        icon = Icons.help_outline;
    }
    return Icon(icon, color: _getStatusColor());
  }

  Color _getStatusColor() {
    switch (estimate.status) {
      case 'not_started':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'likely_finished':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
