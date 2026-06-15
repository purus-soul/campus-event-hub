import 'dart:typed_data';
import '../main.dart';
import '../models/event_model.dart';

class EventService {
  /// Fetch all upcoming events (today or later), optionally filtered by category
  static Future<List<EventModel>> getEvents({
    String? category,
    String? currentUserUid,
  }) async {
    var query = supabase.from('events').select();

    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }

    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await query.gte('event_date', today).order('event_date', ascending: true);

    final events = (data as List).map((e) => EventModel.fromMap(e)).toList();

    // Fetch attendee counts and join status
    for (final event in events) {
      final attendees = await supabase
          .from('event_attendees')
          .select('user_uid')
          .eq('event_id', event.eventId);

      event.attendeeCount = (attendees as List).length;

      if (currentUserUid != null) {
        event.isJoined = attendees.any((a) => a['user_uid'] == currentUserUid);
      }
    }

    return events;
  }

  /// Fetch events posted by a specific user
  static Future<List<EventModel>> getMyPostedEvents(String uid) async {
    final data = await supabase
        .from('events')
        .select()
        .eq('organizer_uid', uid)
        .order('event_date', ascending: true);

    final events = (data as List).map((e) => EventModel.fromMap(e)).toList();
    for (final event in events) {
      final attendees = await supabase
          .from('event_attendees')
          .select('user_uid')
          .eq('event_id', event.eventId);
      event.attendeeCount = (attendees as List).length;
    }
    return events;
  }

  /// Fetch events a user has joined
  static Future<List<EventModel>> getMyJoinedEvents(String uid) async {
    final joined = await supabase
        .from('event_attendees')
        .select('event_id')
        .eq('user_uid', uid);

    final eventIds = (joined as List).map((j) => j['event_id'] as String).toList();
    if (eventIds.isEmpty) return [];

    final data = await supabase
        .from('events')
        .select()
        .inFilter('event_id', eventIds)
        .order('event_date', ascending: true);

    final events = (data as List).map((e) => EventModel.fromMap(e)).toList();
    for (final event in events) {
      event.isJoined = true;
      final attendees = await supabase
          .from('event_attendees')
          .select('user_uid')
          .eq('event_id', event.eventId);
      event.attendeeCount = (attendees as List).length;
    }
    return events;
  }

  /// Create a new event
  static Future<void> createEvent({
    required String title,
    required String description,
    required String organizerUid,
    required String organizerName,
    required DateTime eventDate,
    String? eventTime,
    required String venue,
    required String category,
    String? imageUrl,
    int? maxCapacity,
  }) async {
    await supabase.from('events').insert({
      'title': title,
      'description': description,
      'organizer_uid': organizerUid,
      'organizer_name': organizerName,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'event_time': eventTime,
      'venue': venue,
      'category': category,
      'image_url': imageUrl,
      'max_capacity': maxCapacity,
    });
  }

  /// Join an event
  static Future<void> joinEvent(String eventId, String userUid) async {
    await supabase.from('event_attendees').insert({
      'event_id': eventId,
      'user_uid': userUid,
    });
  }

  /// Leave an event
  static Future<void> leaveEvent(String eventId, String userUid) async {
    await supabase
        .from('event_attendees')
        .delete()
        .eq('event_id', eventId)
        .eq('user_uid', userUid);
  }

  /// Delete an event (organizer only)
  static Future<void> deleteEvent(String eventId) async {
    await supabase.from('events').delete().eq('event_id', eventId);
  }

  /// Get list of attendees for an event
  static Future<List<Map<String, dynamic>>> getAttendees(String eventId) async {
    final data = await supabase
        .from('event_attendees')
        .select('user_uid, users(name, department, batch)')
        .eq('event_id', eventId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Upload event image to Supabase Storage, returns public URL
  static Future<String> uploadEventImageBytes(Uint8List bytes, String fileName) async {
    final path = 'events/$fileName';
    await supabase.storage.from('event-images').uploadBinary(path, bytes);
    return supabase.storage.from('event-images').getPublicUrl(path);
  }
}
