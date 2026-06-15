class EventModel {
  final String eventId;
  final String title;
  final String description;
  final String organizerUid;
  final String organizerName;
  final DateTime eventDate;
  final String? eventTime;
  final String venue;
  final String category;
  final String? imageUrl;
  final int? maxCapacity;
  int attendeeCount;
  bool isJoined;

  EventModel({
    required this.eventId,
    required this.title,
    required this.description,
    required this.organizerUid,
    required this.organizerName,
    required this.eventDate,
    this.eventTime,
    required this.venue,
    required this.category,
    this.imageUrl,
    this.maxCapacity,
    this.attendeeCount = 0,
    this.isJoined = false,
  });

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      eventId: map['event_id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      organizerUid: map['organizer_uid'] ?? '',
      organizerName: map['organizer_name'] ?? '',
      eventDate: DateTime.parse(map['event_date']),
      eventTime: map['event_time'],
      venue: map['venue'] ?? '',
      category: map['category'] ?? 'General',
      imageUrl: map['image_url'],
      maxCapacity: map['max_capacity'],
    );
  }
}
