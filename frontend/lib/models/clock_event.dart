class ClockEvent {
  const ClockEvent({
    required this.id,
    required this.eventType,
    required this.recordedAt,
    this.latitude,
    this.longitude,
    this.isCorrection = false,
    this.workCenter,
    this.workCenterAddress,
    this.workCenterLatitude,
    this.workCenterLongitude,
  });

  final String id;
  final String eventType;
  final DateTime recordedAt;
  final double? latitude;
  final double? longitude;
  final bool isCorrection;
  final String? workCenter;
  final String? workCenterAddress;
  final double? workCenterLatitude;
  final double? workCenterLongitude;

  factory ClockEvent.fromJson(Map<String, dynamic> json) {
    return ClockEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isCorrection: json['is_correction'] == true,
      workCenter: json['work_center'] as String?,
      workCenterAddress: json['work_center_address'] as String?,
      workCenterLatitude: (json['work_center_latitude'] as num?)?.toDouble(),
      workCenterLongitude: (json['work_center_longitude'] as num?)?.toDouble(),
    );
  }

  bool get hasGps => latitude != null && longitude != null;

  bool get hasMapCoordinates =>
      hasGps ||
      (workCenterLatitude != null && workCenterLongitude != null);

  double? get mapLat => latitude ?? workCenterLatitude;

  double? get mapLng => longitude ?? workCenterLongitude;

  Map<String, dynamic> toIncidentExtra() => {
        'mode': 'wrong_time',
        'scenario': 'wrong_time',
        'event_type': eventType,
        'related_event_id': id,
        'proposed_at': recordedAt.toUtc().toIso8601String(),
      };
}
