import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_map_location_picker.dart';
import '../config/google_maps_config.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  final String selectedRole;

  const SignupScreen({super.key, required this.selectedRole});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Role-specific controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  // Additional role-specific controllers
  final TextEditingController _businessAddressController =
      TextEditingController();
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _maxDistanceController = TextEditingController();
  final TextEditingController _volunteerCapacityController =
      TextEditingController();

  // Recipient-specific controllers
  final TextEditingController _operatingHoursStartController =
      TextEditingController();
  final TextEditingController _operatingHoursEndController =
      TextEditingController();

  String? _selectedVehicleType;
  String? _selectedOrgType;
  final List<String> _selectedFoodTypes = [];
  final List<String> _selectedDietaryRestrictions = [];
  final List<String> _selectedPreferredFoodTypes = [];

  // Location variable - REMOVED unused _locationAddress
  LatLng? _selectedLocation;

  late String _selectedRole;
  bool _saveLogin = true;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.selectedRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _orgNameController.dispose();
    _capacityController.dispose();
    _businessAddressController.dispose();
    _registrationNumberController.dispose();
    _contactNumberController.dispose();
    _maxDistanceController.dispose();
    _volunteerCapacityController.dispose();
    _operatingHoursStartController.dispose();
    _operatingHoursEndController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _getRoleSpecificDetails() {
    switch (_selectedRole) {
      case 'donor':
        return {
          'businessName': _businessNameController.text,
          'businessType': _businessTypeController.text,
          'businessAddress': _businessAddressController.text.isNotEmpty
              ? _businessAddressController.text
              : _addressController.text,
          'registrationNumber': _registrationNumberController.text,
          'foodTypes': _selectedFoodTypes,
        };
      case 'recipient':
        final recipientDetails = {
          'organizationName': _orgNameController.text,
          'organizationType': _selectedOrgType ?? 'other',
          'address': _addressController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 50,
          'dietaryRestrictions': _selectedDietaryRestrictions,
          'preferredFoodTypes': _selectedPreferredFoodTypes,
          'currentLoad': 0,
          'isActive': true,
        };

        // Add location if available
        if (_selectedLocation != null) {
          recipientDetails['location'] = {
            'lat': _selectedLocation!.latitude,
            'lng': _selectedLocation!.longitude,
          };
        }

        // Add operating hours if provided
        if (_operatingHoursStartController.text.isNotEmpty &&
            _operatingHoursEndController.text.isNotEmpty) {
          recipientDetails['operatingHours'] = {
            'start': _operatingHoursStartController.text,
            'end': _operatingHoursEndController.text,
          };
        }

        return recipientDetails;
      case 'volunteer':
        return {
          'vehicleType': _selectedVehicleType,
          'contactNumber': _contactNumberController.text.isNotEmpty
              ? _contactNumberController.text
              : _phoneController.text,
          'maxDistance': int.tryParse(_maxDistanceController.text) ?? 20,
          'capacity': int.tryParse(_volunteerCapacityController.text) ?? 10,
          'availability': [],
          'isAvailable': true,
          'currentTasks': 0,
          'volunteerMetrics': {
            'completedDeliveries': 0,
            'totalDistance': 0,
            'averageRating': 0,
            'reliabilityScore': 100,
          },
        };
      default:
        return null;
    }
  }

  Widget _buildRoleSpecificFields() {
    switch (_selectedRole) {
      case 'donor':
        return Column(
          children: [
            TextFormField(
              controller: _businessNameController,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your business name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessTypeController,
              decoration: const InputDecoration(
                labelText: 'Business Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your business type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessAddressController,
              decoration: const InputDecoration(
                labelText: 'Business Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: 'Leave empty to use personal address',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _registrationNumberController,
              decoration: const InputDecoration(
                labelText: 'Registration Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assignment),
              ),
            ),
          ],
        );
      case 'recipient':
        return Column(
          children: [
            TextFormField(
              controller: _orgNameController,
              decoration: const InputDecoration(
                labelText: 'Organization Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your organization name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              // FIXED: Use initialValue instead of value
              initialValue: _selectedOrgType,
              decoration: const InputDecoration(
                labelText: 'Organization Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'shelter', child: Text('Shelter')),
                DropdownMenuItem(
                    value: 'community_kitchen',
                    child: Text('Community Kitchen')),
                DropdownMenuItem(value: 'food_bank', child: Text('Food Bank')),
                DropdownMenuItem(
                    value: 'religious', child: Text('Religious Organization')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedOrgType = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select organization type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(
                labelText: 'Capacity (people) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter capacity';
                }
                final capacity = int.tryParse(value);
                if (capacity == null || capacity < 1) {
                  return 'Please enter a valid capacity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Enhanced Google Map Location Picker for Recipient
            GoogleMapLocationPicker(
              initialAddress: _addressController.text,
              initialLocation: _selectedLocation,
              googleApiKey: GoogleMapsConfig.googleMapsApiKey,
              onLocationSelected: (LatLng location, String address) {
                setState(() {
                  _selectedLocation = location;
                  // Auto-fill address field if empty
                  if (_addressController.text.isEmpty) {
                    _addressController.text = address;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Operating Hours Section
            const Text(
              'Operating Hours (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _operatingHoursStartController,
                    decoration: const InputDecoration(
                      labelText: 'Start Time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                      hintText: '09:00',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _operatingHoursEndController,
                    decoration: const InputDecoration(
                      labelText: 'End Time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                      hintText: '17:00',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Format: HH:MM (24-hour format)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      case 'volunteer':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              // FIXED: Use initialValue instead of value
              initialValue: _selectedVehicleType,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              items: const [
                DropdownMenuItem(value: 'bike', child: Text('Bike')),
                DropdownMenuItem(value: 'car', child: Text('Car')),
                DropdownMenuItem(value: 'van', child: Text('Van')),
                DropdownMenuItem(value: 'truck', child: Text('Truck')),
                DropdownMenuItem(value: 'none', child: Text('None')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedVehicleType = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select vehicle type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNumberController,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: 'Leave empty to use main phone number',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxDistanceController,
              decoration: const InputDecoration(
                labelText: 'Max Distance (km)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
                hintText: 'Default: 20 km',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volunteerCapacityController,
              decoration: const InputDecoration(
                labelText: 'Delivery Capacity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
                hintText: 'Default: 10 deliveries',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    debugPrint("in signup screen with role: $_selectedRole");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role Display
                TextFormField(
                  controller:
                      TextEditingController(text: _selectedRole.toUpperCase()),
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // Role-specific fields
                _buildRoleSpecificFields(),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Address Field
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Save Login Info
                CheckboxListTile(
                  title: const Text('Remember me'),
                  value: _saveLogin,
                  onChanged: (value) {
                    setState(() {
                      _saveLogin = value!;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _signUp,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign Up', style: TextStyle(fontSize: 16)),
                  ),
                ),

                // Error Message
                if (authProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      authProvider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    debugPrint('signUp started for role: $_selectedRole');
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    // Additional validation for recipient location
    if (_selectedRole == 'recipient' && _selectedLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please select your organization location on the map')),
        );
      }
      return;
    }

    try {
      await Provider.of<AuthProvider>(context, listen: false).register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole,
        phone: _phoneController.text,
        address: _addressController.text,
        saveLogin: _saveLogin,
        donorDetails:
            _selectedRole == 'donor' ? _getRoleSpecificDetails() : null,
        recipientDetails:
            _selectedRole == 'recipient' ? _getRoleSpecificDetails() : null,
        volunteerDetails:
            _selectedRole == 'volunteer' ? _getRoleSpecificDetails() : null,
      );

      // Navigate to dashboard after successful registration
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }

      debugPrint('register call finished');
    } catch (e) {
      debugPrint('register failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    }
  }
}
