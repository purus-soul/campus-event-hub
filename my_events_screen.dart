import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<EventModel> _posted = [];
  List<EventModel> _joined = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService.getCurrentUser();
    final uid = user['uid']!;

    final posted = await EventService.getMyPostedEvents(uid);
    final joined = await EventService.getMyJoinedEvents(uid);

    if (!mounted) return;
    setState(() {
      _posted = posted;
      _joined = joined;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('My Events', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Posted by me'),
              Tab(text: 'Joined'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_posted, 'You haven\'t posted any events yet'),
                      _buildList(_joined, 'You haven\'t joined any events yet'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<EventModel> events, String emptyMessage) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final dateStr = DateFormat('EEE, MMM d').format(event.eventDate);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$dateStr • ${event.venue}\n${event.attendeeCount} attending'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.eventId)),
                );
                _load();
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
