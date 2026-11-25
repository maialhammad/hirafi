
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/db_constants.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String fullName;
  final String role;

  const ProfileScreen({
    super.key,
    required this.fullName,
    required this.role,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String currentName;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    currentName = widget.fullName;
  }

  String get roleTitle {
    switch (widget.role) {
      case Role.customer:
        return 'عميل';
      case Role.craftsman:
        return 'حرفي';
      case Role.admin:
        return 'مدير النظام';
      default:
        return 'مستخدم';
    }
  }

  Future<void> editName() async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الاسم'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'الاسم الكامل',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName == null || newName.isEmpty || newName == currentName) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection(Col.users)
          .doc(user.uid)
          .update({
        Field.name: newName,
        Field.updatedAt: FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        currentName = newName;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الاسم بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث الاسم: $e')),
      );
    }
  }
  Future<void> editEmail() async {
  final controller = TextEditingController();

  final newEmail = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تغيير البريد الإلكتروني'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          hintText: 'البريد الإلكتروني الجديد',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text('إرسال رابط التحقق'),
        ),
      ],
    ),
  );

  controller.dispose();

  if (newEmail == null || newEmail.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await user.verifyBeforeUpdateEmail(newEmail);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال رابط التحقق إلى بريدك الجديد'),
      ),
    );
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? e.code)),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $e')),
    );
  }
}
Future<void> refreshEmail() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  try {
    await user.reload();

    final updatedUser = FirebaseAuth.instance.currentUser;

    if (updatedUser != null && updatedUser.email != null) {
      await FirebaseFirestore.instance
          .collection(Col.users)
          .doc(updatedUser.uid)
          .update({
        Field.email: updatedUser.email,
        Field.updatedAt: FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث البريد الإلكتروني بنجاح'),
        ),
      );

      setState(() {});
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $e')),
    );
  }
}

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget profileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 25),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text(
            'الملف الشخصي',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF292929),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const CircleAvatar(
                radius: 55,
                backgroundColor: Color(0xFFFFEFE9),
                child: Icon(
                  Icons.person,
                  size: 65,
                  color: Color(0xFFFF6B35),
                ),
              ),

              const SizedBox(height: 15),

              Text(
                currentName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                roleTitle,
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 30),

              profileItem(
                icon: Icons.person_outline,
                title: 'الاسم الكامل',
                value: currentName,
              ),

              profileItem(
                icon: Icons.email_outlined,
                title: 'البريد الإلكتروني',
                value: user?.email ?? 'غير متوفر',
              ),

              profileItem(
                icon: Icons.badge_outlined,
                title: 'نوع الحساب',
                value: roleTitle,
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : editName,
                  icon: const Icon(Icons.edit),
                  label: Text(isSaving ? 'جاري الحفظ...' : 'تعديل الاسم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: editEmail,
    icon: const Icon(Icons.email_outlined),
    label: const Text('تغيير البريد الإلكتروني'),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFFF6B35),
      side: const BorderSide(
        color: Color(0xFFFF6B35),
      ),
    ),
  ),
),
const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: refreshEmail,
    icon: const Icon(Icons.verified_outlined),
    label: const Text('تحديث البريد بعد التحقق'),
  ),
),

              SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: logout,
    icon: const Icon(Icons.logout, color: Colors.red),
    label: const Text(
      'تسجيل الخروج',
      style: TextStyle(color: Colors.red),
    ),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.red),
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}
