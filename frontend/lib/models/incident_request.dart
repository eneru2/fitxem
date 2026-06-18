class IncidentRequest {
  const IncidentRequest({
    required this.id,
    required this.eventType,
    required this.proposedAt,
    required this.reason,
    required this.incidentType,
    required this.status,
    required this.createdAt,
    this.relatedEventId,
    this.originalRecordedAt,
    this.employeeName,
  });

  final String id;
  final String eventType;
  final DateTime proposedAt;
  final String reason;
  final String incidentType;
  final String status;
  final DateTime createdAt;
  final String? relatedEventId;
  final DateTime? originalRecordedAt;
  final String? employeeName;

  factory IncidentRequest.fromJson(Map<String, dynamic> json) {
    return IncidentRequest(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      proposedAt: DateTime.parse(json['proposed_at'] as String).toLocal(),
      reason: json['reason'] as String,
      incidentType: json['incident_type'] as String? ?? 'other',
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      relatedEventId: json['related_event_id'] as String?,
      originalRecordedAt: json['original_recorded_at'] != null
          ? DateTime.parse(json['original_recorded_at'] as String).toLocal()
          : null,
      employeeName: json['employee_name'] as String?,
    );
  }
}
