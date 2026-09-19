import 'package:intl/intl.dart';

/// Formats an ISO-8601 timestamp string (as returned by the backend, e.g.
/// current_quantity_updated_at) into a local, human-readable string.
/// Returns [fallback] when [isoTimestamp] is null or unparsable.
String formatTimestamp(String? isoTimestamp, {String fallback = 'No readings yet'}) {
  if (isoTimestamp == null) return fallback;
  final parsed = DateTime.tryParse(isoTimestamp);
  if (parsed == null) return fallback;
  return DateFormat.yMd().add_jm().format(parsed.toLocal());
}
