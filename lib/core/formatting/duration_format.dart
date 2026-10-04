/// "0:07", "1:05" o "1:02:03". Vacío si no se conoce la duración.
String formatDuration(Duration? duration) {
  if (duration == null) return '';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}
