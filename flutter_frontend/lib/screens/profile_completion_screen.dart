import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Role-specific controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  String? _selectedVehicleType;

  String _selectedRole = 'donor';
  bool _saveLogin = true;

  Map<String, dynamic>? _getRoleSpecificDetails() {
    switch (_selectedRole) {
      case 'donor':
        return {
          'businessName': _businessNameController.text,
          'businessType': _businessTypeController.text,
        };
      case 'recipient':
        return {
          'organizationName': _orgNameController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 0,
        };
      case 'volunteer':
        return {
          'vehicleType': _selectedVehicleType,
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
                labelText: 'Business Name',
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
                labelText: 'Business Type',
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
          ],
        );
      case 'recipient':
        return Column(
          children: [
            TextFormField(
              controller: _orgNameController,
              decoration: const InputDecoration(
                labelText: 'Organization Name',
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
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(
                labelText: 'Capacity (people)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter capacity';
                }
                return null;
              },
            ),
          ],
        );
      case 'volunteer':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue:  _selectedVehicleType,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
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
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .completeGoogleProfile(
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

      // Navigate to dashboard after successful profile completion
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      debugPrint('Profile completion failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.person_add, size: 60, color: Colors.blue),
                const SizedBox(height: 10),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please provide additional information to complete your profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Role Selection - FIXED: Using DropdownButtonFormField correctly
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Select Your Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'donor', child: Text('Donor')),
                    DropdownMenuItem(
                      value: 'recipient',
                      child: Text('Recipient Organization'),
                    ),
                    DropdownMenuItem(
                      value: 'volunteer',
                      child: Text('Volunteer'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Role-specific fields
                _buildRoleSpecificFields(),
                const SizedBox(height: 20),

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
                const SizedBox(height: 20),

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
                const SizedBox(height: 20),

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

                // Complete Profile Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _completeProfile,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Complete Profile',
                            style: TextStyle(fontSize: 16)),
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
}
