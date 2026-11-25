
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/db_constants.dart';
import 'home_screen.dart';
import 'craftsman_profile_setup_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  


Future<void> login() async {
  if (emailController.text.trim().isEmpty ||
      passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter email and password')),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    final credential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('Unable to identify user');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db
        .collection(Col.users)
        .doc(firebaseUser.uid)
        .get();

    if (!userDoc.exists) {
      await FirebaseAuth.instance.signOut();
      throw Exception('User profile not found');
    }

    final userData = userDoc.data()!;
    final role = userData[Field.role];
    final fullName = userData[Field.name] ?? 'User';
    final status = userData[Field.status];

    if (status != UserStatus.active) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Your account is not active');
    }

    if (role != Role.customer &&
        role != Role.craftsman &&
        role != Role.admin) {
      await FirebaseAuth.instance.signOut();
      throw Exception('Invalid user role');
    }

    String effectiveRole = role;

    if (role == Role.craftsman) {
      final craftsmanDoc = await db
          .collection(Col.craftsmen)
          .doc(firebaseUser.uid)
          .get();

      if (!mounted) return;

      // Craftsman has not completed professional profile
      if (!craftsmanDoc.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const CraftsmanProfileSetupScreen(),
          ),
        );
        return;
      }

      final craftsmanData = craftsmanDoc.data()!;

      final isApproved =
          craftsmanData[Field.approved] == true &&
          craftsmanData[Field.verificationStatus] ==
              VerificationStatus.approved;

      // Pending or rejected craftsman uses customer interface
      effectiveRole = isApproved ? Role.craftsman : Role.customer;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          role: effectiveRole,
          fullName: fullName,
        ),
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.code} - ${e.message}'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}


  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.handyman,
                  size: 75,
                  color: Color(0xFF245C4F),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to Hirafi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 35),

                const Text('Email'),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Password'),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF245C4F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Color(0xFF245C4F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
