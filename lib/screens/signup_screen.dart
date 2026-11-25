
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = 'customer';
  bool isLoading = false;

  

Future<void> signup() async {
  if (nameController.text.trim().isEmpty ||
      emailController.text.trim().isEmpty ||
      passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill in all fields')),
    );
    return;
  }

  setState(() => isLoading = true);

  User? newUser;

  try {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    newUser = credential.user;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(newUser!.uid)
        .set({
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'role': selectedRole,
      'status': 'active',
      'language': 'ar',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedRole == 'craftsman'
              ? 'Account created! Please log in to complete your professional profile.'
              : 'Account created successfully!',
        ),
      ),
    );

    Navigator.pop(context);

  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'Registration failed')),
    );

  } catch (e) {
    if (newUser != null) {
      try {
       await newUser.delete();
      } catch (_) {}
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Something went wrong: $e')),
    );

  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: const Color(0xFF245C4F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Join Hirafi!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Register As:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            RadioGroup<String>(
  groupValue: selectedRole,
  onChanged: (value) {
    setState(() {
      selectedRole = value!;
    });
  },
  child: Column(
    children: [
      RadioListTile<String>(
        title: const Text('Customer'),
        value: 'customer',
      ),
      RadioListTile<String>(
        title: const Text('Craftsman'),
        value: 'craftsman',
      ),
    ],
  ),
),

            

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isLoading ? null : signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245C4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
