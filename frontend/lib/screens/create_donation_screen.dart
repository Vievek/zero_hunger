import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  String _donationType = 'normal';
  final List<String> _selectedImages = [];
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _expectedQuantityController =
      TextEditingController();
  DateTime? _scheduledPickup;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _addressController.dispose();
    _expectedQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Donation'),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      body: _isSubmitting
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Donation Type
                    _buildDonationTypeSelector(),
                    const SizedBox(height: 20),

                    // Image Upload
                    _buildImageUploadSection(),
                    const SizedBox(height: 20),

                    // Quantity
                    _buildQuantitySection(),
                    const SizedBox(height: 20),

                    // Expected Quantity (for bulk)
                    if (_donationType == 'bulk')
                      _buildExpectedQuantitySection(),

                    // Location
                    _buildLocationSection(),
                    const SizedBox(height: 20),

                    // Scheduled Pickup (for bulk)
                    if (_donationType == 'bulk') _buildScheduledPickupSection(),

                    const SizedBox(height: 30),

                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Creating your donation...'),
          SizedBox(height: 10),
          Text(
            'AI is analyzing your food images',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donation Type *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Normal: Daily surplus food\nBulk: Event or large quantity donations',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'normal',
              label: Text('Normal'),
              icon: Icon(Icons.restaurant),
            ),
            ButtonSegment<String>(
              value: 'bulk',
              label: Text('Bulk'),
              icon: Icon(Icons.event),
            ),
          ],
          selected: {_donationType},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _donationType = newSelection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Food Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedImages.isEmpty
              ? 'Add photos for AI analysis (recommended)'
              : '${_selectedImages.length} image(s) selected',
          style: TextStyle(
            fontSize: 12,
            color: _selectedImages.isEmpty ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._selectedImages.asMap().entries.map(
                  (entry) => Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(File(entry.value)),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(entry.key);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(
                                  229), // Fixed deprecated withOpacity
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_photo_alternate,
                        size: 35, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Add Photo',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'AI will analyze these images to generate description, categories, and safety information',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantity *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 10',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., portions, kg, plates',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter unit';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpectedQuantitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expected Quantity (Bulk) *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _expectedQuantityController,
          decoration: const InputDecoration(
            labelText: 'Estimated total quantity',
            border: OutlineInputBorder(),
            hintText: 'e.g., 50 plates, 20kg rice, 100 sandwiches',
            prefixIcon: Icon(Icons.assessment),
          ),
          validator: (value) {
            if (_donationType == 'bulk' && (value == null || value.isEmpty)) {
              return 'Please provide estimated quantity for bulk donation';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pickup Location *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Full pickup address',
            border: OutlineInputBorder(),
            hintText: 'Street address, city, postal code',
            prefixIcon: Icon(Icons.location_on),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter pickup address';
            }
            if (value.length < 10) {
              return 'Please provide a complete address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildScheduledPickupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scheduled Pickup *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'For bulk donations, schedule when the food will be ready for pickup',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
                color: _scheduledPickup == null ? Colors.orange : Colors.green),
            borderRadius: BorderRadius.circular(8),
            color: _scheduledPickup == null
                ? Colors.orange.shade50
                : Colors.green.shade50,
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color:
                      _scheduledPickup == null ? Colors.orange : Colors.green,
                ),
                title: Text(
                  _scheduledPickup == null
                      ? 'Select date and time for pickup'
                      : 'Scheduled for: ${_formatDateTime(_scheduledPickup!)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color:
                        _scheduledPickup == null ? Colors.orange : Colors.green,
                  ),
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _selectDateTime(),
              ),
              if (_scheduledPickup == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Pickup time is required for bulk donations',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitDonation,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'Create Donation',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = now.add(const Duration(days: 1));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Select pickup date',
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 12, minute: 0),
        helpText: 'Select pickup time',
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _scheduledPickup = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors above')),
      );
      return;
    }

    if (_donationType == 'bulk') {
      if (_scheduledPickup == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please select scheduled pickup time for bulk donations')),
        );
        return;
      }
      if (_expectedQuantityController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please provide expected quantity for bulk donation')),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final donation = Donation(
        donorId: '', // Will be set by backend
        type: _donationType,
        status: 'pending',
        images: [],
        categories: [], // Will be set by AI
        tags: [], // Will be set by AI
        quantity: {
          'amount': double.parse(_quantityController.text),
          'unit': _unitController.text,
        },
        expectedQuantity:
            _donationType == 'bulk' ? _expectedQuantityController.text : null,
        scheduledPickup: _scheduledPickup,
        pickupAddress: _addressController.text,
        location: {
          'lat': 0.0, // In production, integrate with geolocation service
          'lng': 0.0,
        },
        createdAt: DateTime.now(),
      );

      await Provider.of<DonationProvider>(
        context,
        listen: false,
      ).createDonation(donation, _selectedImages);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedImages.isEmpty
                ? 'Donation created successfully!'
                : 'Donation created! AI is analyzing your images...'),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create donation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
