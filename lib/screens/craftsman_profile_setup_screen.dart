
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'home_screen.dart';

class CraftsmanProfileSetupScreen extends StatefulWidget {
  const CraftsmanProfileSetupScreen({super.key});

  @override
  State<CraftsmanProfileSetupScreen> createState() =>
      _CraftsmanProfileSetupScreenState();
}

class _CraftsmanProfileSetupScreenState
    extends State<CraftsmanProfileSetupScreen> {
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final priceController = TextEditingController();
  final nationalIdController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  Uint8List? frontBytes;
  Uint8List? backBytes;

  final Set<String> selectedCategories = {};

  bool isLoading = false;

  final Map<String, String> categories = {
    'plumbing': 'Plumbing - سباكة',
    'electrical': 'Electrical - كهرباء',
    'carpentry': 'Carpentry - نجارة',
    'painting': 'Painting - دهان',
    'ac_repair': 'AC Repair - تكييف وتبريد',
    'cleaning': 'Cleaning - تنظيف',
  };

  Future<void> pickIdImage(bool isFront) async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        if (isFront) {
          frontBytes = bytes;
        } else {
          backBytes = bytes;
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  Future<void> saveProfile() async {
    final phone = phoneController.text.trim().replaceAll(
      RegExp(r'[\s-]'),
      '',
    );

    final city = cityController.text.trim();
    final nationalId = nationalIdController.text.trim();
    final price = double.tryParse(priceController.text.trim());

    if (phone.length < 9 ||
        phone.length > 15 ||
        !RegExp(r'^\+?[0-9]+$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(nationalId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('National ID must contain exactly 10 digits'),
        ),
      );
      return;
    }

    if (city.isEmpty ||
        selectedCategories.isEmpty ||
        price == null ||
        price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields correctly'),
        ),
      );
      return;
    }

    if (frontBytes == null || backBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both sides of your ID'),
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final uid = currentUser.uid;

      final userRef = db.collection('users').doc(uid);
      final craftsmanRef = db.collection('craftsmen').doc(uid);
      final verificationRef = db.collection('verifications').doc(uid);

      final userDoc = await userRef.get();

      if (!userDoc.exists ||
          userDoc.data()?['role'] != 'craftsman' ||
          userDoc.data()?['status'] != 'active') {
        throw Exception('This account is not an active craftsman account');
      }

      final craftsmanDoc = await craftsmanRef.get();

      if (craftsmanDoc.exists) {
        throw Exception('Your professional profile already exists');
      }

      final name = userDoc.data()?['name'] ?? '';

      final batch = db.batch();

      batch.update(userRef, {
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(craftsmanRef, {
        'name': name,
        'city': city,
        'categoryIds': selectedCategories.toList(),
        'pricePerHour': price,
        'verificationStatus': 'pending',
        'approved': false,
        'rating': 0.0,
        'ratingCount': 0,
        'ratingSum': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(verificationRef, {
        'nationalId': nationalId,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your application was submitted. Waiting for admin approval.',
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            role: 'customer',
            fullName: name,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget buildImagePicker({
    required String title,
    required bool isFront,
    required Uint8List? bytes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isLoading ? null : () => pickIdImage(isFront),
          icon: const Icon(Icons.upload_file),
          label: Text(
            bytes == null ? 'Choose image' : 'Change image',
          ),
        ),
        if (bytes != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    cityController.dispose();
    priceController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Professional Profile'),
        backgroundColor: const Color(0xFF245C4F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tell us about your work',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: nationalIdController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'National ID Number',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Choose your professions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.entries.map((entry) {
                return FilterChip(
                  label: Text(entry.value),
                  selected: selectedCategories.contains(entry.key),
                  onSelected: isLoading
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              selectedCategories.add(entry.key);
                            } else {
                              selectedCategories.remove(entry.key);
                            }
                          });
                        },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price per hour (JOD)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Identity Verification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select both sides of your ID for preview. '
              'Images are not uploaded or saved.',
            ),
            const SizedBox(height: 12),

            buildImagePicker(
              title: 'Front side of ID',
              isFront: true,
              bytes: frontBytes,
            ),

            const SizedBox(height: 20),

            buildImagePicker(
              title: 'Back side of ID',
              isFront: false,
              bytes: backBytes,
            ),

            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: isLoading ? null : saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245C4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text('Submit for Admin Approval'),
            ),
          ],
        ),
      ),
    );
  }
}
