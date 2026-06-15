import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCategory = 'General';
  XFile? _pickedImage;
  bool _loading = false;

  final List<String> _categories = ['Tech', 'Cultural', 'Sports', 'Workshop', 'Seminar', 'General'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await AuthService.getCurrentUser();

      String? imageUrl;
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final fileName = '${const Uuid().v4()}.jpg';
        imageUrl = await EventService.uploadEventImageBytes(bytes, fileName);
      }

      String? timeStr;
      if (_selectedTime != null) {
        final hour = _selectedTime!.hour.toString().padLeft(2, '0');
        final minute = _selectedTime!.minute.toString().padLeft(2, '0');
        timeStr = '$hour:$minute';
      }

      await EventService.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        organizerUid: user['uid']!,
        organizerName: user['name']!,
        eventDate: _selectedDate!,
        eventTime: timeStr,
        venue: _venueController.text.trim(),
        category: _selectedCategory,
        imageUrl: imageUrl,
        maxCapacity: _capacityController.text.trim().isEmpty ? null : int.tryParse(_capacityController.text.trim()),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post event: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post an Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _pickedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_pickedImage!.path), fit: BoxFit.cover, width: double.infinity),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Add event image (optional)', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter event title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a description' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime == null ? 'Select Time' : _selectedTime!.format(context)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter the venue' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Capacity (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Leave blank for unlimited',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Post Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    super.dispose();
  }
}
