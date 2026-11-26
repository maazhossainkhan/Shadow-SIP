class CallLogItem {
  const CallLogItem({
    required this.peer,
    required this.outgoing,
    required this.startedAt,
    required this.durationSeconds,
    required this.result,
  });

  final String peer;
  final bool outgoing;
  final DateTime startedAt;
  final int durationSeconds;
  final String result;

  Map<String, Object?> toJson() => {
        'peer': peer,
        'outgoing': outgoing,
        'startedAt': startedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'result': result,
      };

  factory CallLogItem.fromJson(Map<String, dynamic> json) => CallLogItem(
        peer: json['peer'] as String? ?? 'Unknown caller',
        outgoing: json['outgoing'] as bool? ?? false,
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.now(),
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        result: json['result'] as String? ?? 'Ended',
      );
}
