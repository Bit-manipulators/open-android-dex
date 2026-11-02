class NotificationItem {
  final String id;
  final String packageName;
  final String title;
  final String body;
  final DateTime timestamp;
  final String category;
  final bool isOngoing;

  const NotificationItem({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
    this.category = 'msg',
    this.isOngoing = false,
  });

  String get appName {
    if (packageName.contains('.')) {
      final parts = packageName.split('.');
      final last = parts.last;
      return last[0].toUpperCase() + last.substring(1);
    }
    return packageName;
  }
}
