import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'my_events_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const EventFeedTab(),
      const MyEventsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_selectedTab],
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                );
                setState(() {}); // refresh feed on return
              },
              icon: const Icon(Icons.add),
              label: const Text('Post Event'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'My Events'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class EventFeedTab extends StatefulWidget {
  const EventFeedTab({super.key});

  @override
  State<EventFeedTab> createState() => _EventFeedTabState();
}

class _EventFeedTabState extends State<EventFeedTab> {
  List<EventModel> _events = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  String? _currentUid;

  final List<String> _categories = ['All', 'Tech', 'Cultural', 'Sports', 'Workshop', 'Seminar', 'General'];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final user = await AuthService.getCurrentUser();
    _currentUid = user['uid'];

    final events = await EventService.getEvents(
      category: _selectedCategory,
      currentUserUid: _currentUid,
    );

    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Upcoming Events', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _loadEvents, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                    _loadEvents();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No upcoming events yet.\nBe the first to post one!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _events.length,
                          itemBuilder: (context, index) => _EventCard(
                            event: _events[index],
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(eventId: _events[index].eventId),
                                ),
                              );
                              _loadEvents();
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d').format(event.eventDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(
                event.imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(event.category, style: const TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (event.isJoined) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('Joined', style: TextStyle(fontSize: 12, color: Colors.white)),
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      if (event.eventTime != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(event.eventTime!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(event.venue, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                      const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${event.attendeeCount}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
