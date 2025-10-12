import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uee_project/screens/donor_dashboard.dart';
import 'dart:io';
import '../providers/donation_provider.dart';
import '../models/donation_model.dart';
import '../widgets/google_map_location_picker.dart';
import '../config/google_maps_config.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  String _donationType = 'normal';
  final List<File> _selectedImages = [];
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _expectedQuantityController =
      TextEditingController();

  final List<String> _selectedCategories = [];
  final List<String> _selectedTags = [];

  DateTime? _scheduledPickup;
  bool _isSubmitting = false;
  bool _isAnalyzingImages = false;

  // Location variable
  LatLng? _selectedLocation;

  final List<String> _availableCategories = [
    'prepared-meal',
    'fruits',
    'vegetables',
    'baked-goods',
    'dairy',
    'meat',
    'seafood',
    'grains',
    'beverages',
    'other'
  ];

  final List<String> _availableTags = [
    'vegetarian',
    'vegan',
    'gluten-free',
    'dairy-free',
    'nut-free',
    'halal',
    'kosher',
    'organic'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _addressController.dispose();
    _expectedQuantityController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      // Get address from coordinates
      await _getAddressFromLatLng(_selectedLocation!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  Future<void> _analyzeImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isAnalyzingImages = true;
    });

    try {
      final donationProvider =
          Provider.of<DonationProvider>(context, listen: false);

      // ✅ Call the actual AI analysis endpoint with proper file handling
      final aiAnalysis =
          await donationProvider.analyzeFoodImages(_selectedImages);

      // Update the form with AI analysis results
      setState(() {
        if (aiAnalysis['description'] != null &&
            _descriptionController.text.isEmpty) {
          _descriptionController.text = aiAnalysis['description'];
        }

        // Clear and add new categories from AI analysis
        _selectedCategories.clear();
        if (aiAnalysis['categories'] != null) {
          _selectedCategories
              .addAll(List<String>.from(aiAnalysis['categories']));
        }

        // Clear and add new tags from AI analysis
        _selectedTags.clear();
        if (aiAnalysis['dietaryInfo'] != null) {
          _selectedTags.addAll(List<String>.from(aiAnalysis['dietaryInfo']));
        }

        _isAnalyzingImages = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI analysis completed!')),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalyzingImages = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI analysis failed: $e')),
        );
      }
    }
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

                    // AI Analysis Button
                    if (_selectedImages.isNotEmpty && !_isAnalyzingImages)
                      _buildAIAnalysisButton(),

                    // Description
                    _buildDescriptionSection(),
                    const SizedBox(height: 20),

                    // Categories & Tags
                    _buildCategoriesSection(),
                    const SizedBox(height: 20),

                    // Quantity
                    _buildQuantitySection(),
                    const SizedBox(height: 20),

                    // Expected Quantity (for bulk)
                    if (_donationType == 'bulk')
                      _buildExpectedQuantitySection(),

                    // Enhanced Google Map Location Picker
                    GoogleMapLocationPicker(
                      initialAddress: _addressController.text,
                      initialLocation: _selectedLocation,
                      googleApiKey: GoogleMapsConfig.googleMapsApiKey,
                      onLocationSelected: (LatLng location, String address) {
                        setState(() {
                          _selectedLocation = location;
                          _addressController.text = address;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Scheduled Pickup (for bulk)
                    if (_donationType == 'bulk') _buildScheduledPickupSection(),

                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Creating your donation...'),
          const SizedBox(height: 10),
          Text(
            _selectedImages.isNotEmpty
                ? 'AI is analyzing your food images using Gemini API for optimal categorization and matching'
                : 'Processing your donation and finding recipients...',
            style: const TextStyle(color: Colors.grey),
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
          'Food Images *',
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
                            image: FileImage(entry.value),
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
                              color: Colors.red.withAlpha(229),
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
              onTap: _showImageSourceDialog,
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

  Widget _buildAIAnalysisButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isAnalyzingImages ? null : _analyzeImages,
        icon: _isAnalyzingImages
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
            _isAnalyzingImages ? 'Analyzing Images...' : 'Analyze with AI'),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Food Description *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Describe the food items',
            border: OutlineInputBorder(),
            hintText:
                'e.g., 20 portions of chicken pasta, 10 sandwiches, fresh fruits...',
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please describe the food items';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Provide a clear description. AI will enhance this with image analysis if photos are added.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories & Tags',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Categories
        const Text('Categories:',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableCategories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(category.replaceAll('-', ' ')),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Dietary Tags
        const Text('Dietary Tags:',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
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

  Widget _buildScheduledPickupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scheduled Pickup *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose how to select images'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
              child: const Text('Gallery'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        // Validate image file before adding
        final File imageFile = File(image.path);

        // Check if file exists and is readable
        if (await imageFile.exists()) {
          // Check file size (max 5MB)
          final fileSize = await imageFile.length();
          if (fileSize > 5 * 1024 * 1024) {
            throw Exception('Image size must be less than 5MB');
          }

          // Check file extension
          final fileName = image.name.toLowerCase();
          final validExtensions = [
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.bmp',
            '.webp'
          ];
          final hasValidExtension =
              validExtensions.any((ext) => fileName.endsWith(ext));

          if (!hasValidExtension) {
            throw Exception(
                'Only image files are allowed (jpg, png, gif, etc.)');
          }

          setState(() {
            _selectedImages.add(imageFile);
          });
        } else {
          throw Exception('Selected file is not accessible');
        }
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
    // Get the provider reference before any async operations
    final donationProvider =
        Provider.of<DonationProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fix the errors above')),
        );
      }
      return;
    }

    if (_donationType == 'bulk') {
      if (_scheduledPickup == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Please select scheduled pickup time for bulk donations')),
          );
        }
        return;
      }
      if (_expectedQuantityController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Please provide expected quantity for bulk donation')),
          );
        }
        return;
      }
    }

    if (_selectedLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a location on the map')),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final donation = Donation(
        donorId: '', // Will be set by backend
        type: _donationType,
        status: 'pending',
        images: [], // Will be set after upload
        description: _descriptionController.text,
        aiDescription: _descriptionController
            .text, // Backend will update this with AI analysis
        categories: _selectedCategories,
        tags: _selectedTags,
        quantity: {
          'amount': double.parse(_quantityController.text),
          'unit': _unitController.text,
        },
        expectedQuantity:
            _donationType == 'bulk' ? _expectedQuantityController.text : null,
        scheduledPickup: _scheduledPickup,
        pickupAddress: _addressController.text,
        location: {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        },
        createdAt: DateTime.now(),
      );

      await donationProvider.createDonation(donation, _selectedImages);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedImages.isEmpty
                ? 'Donation created successfully! Finding recipients...'
                : 'Donation created with Gemini AI analysis! Enhanced categorization and matching in progress...'),
            duration: const Duration(seconds: 4),
          ),
        );
        // Navigate back to donor dashboard by popping all routes and going to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DonorDashboardScreen()),
        );
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
