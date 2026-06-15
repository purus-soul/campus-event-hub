import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventModel? _event;
  bool _loading = true;
  bool _actionLoading = false;
  String _currentUid = '';
  List<Map<String, dynamic>> _attendees = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService.getCurrentUser();
    _currentUid = user['uid'] ?? '';

    final data = await supabase.from('events').select().eq('event_id', widget.eventId).single();
    final event = EventModel.fromMap(data);

    final attendees = await EventService.getAttendees(widget.eventId);
    event.attendeeCount = attendees.length;
    event.isJoined = attendees.any((a) => a['user_uid'] == _currentUid);

    if (!mounted) return;
    setState(() {
      _event = event;
      _attendees = attendees;
      _loading = false;
    });
  }

  Future<void> _toggleJoin() async {
    if (_event == null) return;
    setState(() => _actionLoading = true);

    if (_event!.isJoined) {
      await EventService.leaveEvent(_event!.eventId, _currentUid);
    } else {
      if (_event!.maxCapacity != null && _event!.attendeeCount >= _event!.maxCapacity!) {
        setState(() => _actionLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event is full'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      await EventService.joinEvent(_event!.eventId, _currentUid);
    }

    await _load();
    setState(() => _actionLoading = false);
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await EventService.deleteEvent(widget.eventId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_event == null) {
      return const Scaffold(body: Center(child: Text('Event not found')));
    }

    final event = _event!;
    final isOrganizer = event.organizerUid == _currentUid;
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(event.eventDate);
    final isFull = event.maxCapacity != null && event.attendeeCount >= event.maxCapacity! && !event.isJoined;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title, overflow: TextOverflow.ellipsis),
        actions: isOrganizer
            ? [IconButton(onPressed: _deleteEvent, icon: const Icon(Icons.delete_outline))]
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(
                event.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(event.category)),
                  const SizedBox(height: 12),
                  Text(event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.calendar_today, text: dateStr),
                  if (event.eventTime != null) _InfoRow(icon: Icons.access_time, text: event.eventTime!),
                  _InfoRow(icon: Icons.location_on_outlined, text: event.venue),
                  _InfoRow(icon: Icons.person_outline, text: 'Organized by ${event.organizerName}'),
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: event.maxCapacity != null
                        ? '${event.attendeeCount} / ${event.maxCapacity} joined'
                        : '${event.attendeeCount} joined',
                  ),
                  const SizedBox(height: 16),
                  const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(event.description, style: const TextStyle(fontSize: 15, height: 1.4)),
                  const SizedBox(height: 24),
                  if (!isOrganizer)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_actionLoading || isFull) ? null : _toggleJoin,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: event.isJoined ? Colors.red : null,
                        ),
                        child: _actionLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isFull
                                ? 'Event Full'
                                : event.isJoined
                                    ? 'Leave Event'
                                    : 'Join Event'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_attendees.isNotEmpty) ...[
                    Text('Attendees (${_attendees.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._attendees.map((a) {
                      final user = a['users'] as Map<String, dynamic>?;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user?['name'] ?? 'Unknown'),
                        subtitle: Text('${user?['department'] ?? ''} • ${user?['batch'] ?? ''}'),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
