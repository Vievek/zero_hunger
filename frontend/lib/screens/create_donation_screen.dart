import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String _donationType = 'normal';
  final List<XFile> _selectedImages = [];
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  DateTime? _scheduledPickup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Donation')),
      body: SingleChildScrollView(
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

              // Location
              _buildLocationSection(),
              const SizedBox(height: 20),

              // Scheduled Pickup (for bulk)
              if (_donationType == 'bulk') _buildScheduledPickupSection(),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donation Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._selectedImages
                .map(
                  (image) => Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(image.path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.remove(image);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
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
                )
                .toList(),
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_photo_alternate,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantitySection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter quantity';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _unitController,
            decoration: const InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(),
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
    );
  }

  Widget _buildLocationSection() {
    return TextFormField(
      controller: _addressController,
      decoration: const InputDecoration(
        labelText: 'Pickup Address',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
      maxLines: 2,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter pickup address';
        }
        return null;
      },
    );
  }

  Widget _buildScheduledPickupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scheduled Pickup',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(
            _scheduledPickup == null
                ? 'Select date and time'
                : '${_scheduledPickup!.toLocal()}'.split('.')[0],
          ),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () => _selectDateTime(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final donationProvider = Provider.of<DonationProvider>(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: donationProvider.isLoading ? null : _submitDonation,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: donationProvider.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create Donation', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    }
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
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

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_donationType == 'bulk' && _scheduledPickup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select scheduled pickup time for bulk donations',
          ),
        ),
      );
      return;
    }

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
        scheduledPickup: _scheduledPickup,
        pickupAddress: _addressController.text,
        location: {
          'lat': 0.0, // In production, get from geocoding
          'lng': 0.0,
        },
        createdAt: DateTime.now(),
      );

      await Provider.of<DonationProvider>(
        context,
        listen: false,
      ).createDonation(
        donation,
        _selectedImages.map((image) => image.path).toList(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation created successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create donation: $e')));
    }
  }
}
