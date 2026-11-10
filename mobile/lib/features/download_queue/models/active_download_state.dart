import '../../../core/constants/app_constants.dart';

class DownloadSample {
  final DateTime timestamp;
  final int bytesReceived;

  const DownloadSample({
    required this.timestamp,
    required this.bytesReceived,
  });
}

class ActiveDownloadState {
  final String jobId;
  final String title;
  double progress;
  String step;
  int totalBytes;
  int receivedBytes;
  double speedMbPerSec;
  int? etaSeconds;
  String? error;

  final List<DownloadSample> _samples = [];

  ActiveDownloadState({
    required this.jobId,
    required this.title,
    this.progress = 0.0,
    this.step = 'downloading',
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.speedMbPerSec = 0.0,
    this.etaSeconds,
    this.error,
  });

  /// Record a byte progress measurement and compute the 5-second moving average speed and ETA.
  void recordByteProgress(int currentReceivedBytes, int currentTotalBytes) {
    receivedBytes = currentReceivedBytes;
    totalBytes = currentTotalBytes;

    if (totalBytes > 0) {
      progress = (receivedBytes / totalBytes) * 100.0;
      if (progress > 100.0) progress = 100.0;
    }

    final now = DateTime.now();
    _samples.add(DownloadSample(timestamp: now, bytesReceived: currentReceivedBytes));

    // Retain only samples within the 5-second moving window
    final windowCutoff = now.subtract(
      const Duration(seconds: AppConstants.movingAverageWindowSeconds),
    );
    _samples.removeWhere((sample) => sample.timestamp.isBefore(windowCutoff));

    if (_samples.length >= 2) {
      final oldest = _samples.first;
      final latest = _samples.last;

      final durationMs = latest.timestamp.difference(oldest.timestamp).inMilliseconds;
      final byteDelta = latest.bytesReceived - oldest.bytesReceived;

      if (durationMs > 200 && byteDelta >= 0) {
        final bytesPerSecond = (byteDelta / (durationMs / 1000.0));
        speedMbPerSec = bytesPerSecond / (1024.0 * 1024.0);

        if (bytesPerSecond > 0 && totalBytes > currentReceivedBytes) {
          final remainingBytes = totalBytes - currentReceivedBytes;
          etaSeconds = (remainingBytes / bytesPerSecond).round();
        } else {
          etaSeconds = 0;
        }
      }
    }
  }

  /// Format ETA seconds into mm:ss
  String get etaFormatted {
    if (etaSeconds == null || etaSeconds! <= 0) return '--:--';
    final minutes = etaSeconds! ~/ 60;
    final seconds = etaSeconds! % 60;
    if (minutes > 59) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatted speed string, e.g. '2.45 MB/s'
  String get speedFormatted => '${speedMbPerSec.toStringAsFixed(2)} MB/s';

  ActiveDownloadState copyWith({
    String? jobId,
    String? title,
    double? progress,
    String? step,
    int? totalBytes,
    int? receivedBytes,
    double? speedMbPerSec,
    int? etaSeconds,
    String? error,
  }) {
    final state = ActiveDownloadState(
      jobId: jobId ?? this.jobId,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      step: step ?? this.step,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      speedMbPerSec: speedMbPerSec ?? this.speedMbPerSec,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      error: error ?? this.error,
    );
    return state;
  }
}
