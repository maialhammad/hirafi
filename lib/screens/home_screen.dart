
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/db_constants.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'bookings_screen.dart';
import '../services/create_booking_screen.dart';

const Color orange = Color(0xFFFF6B35);
const Color dark = Color(0xFF292929);
const Color background = Color(0xFFF7F7F7);

class HomeScreen extends StatelessWidget {
  final String role;
  final String fullName;

  const HomeScreen({
    super.key,
    required this.role,
    required this.fullName,
  });

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<Map<String, dynamic>> get features {
    switch (role) {
      case Role.customer:
        return [
          {'title': 'ابحث عن حرفي', 'icon': Icons.search},
          {'title': 'جميع الخدمات', 'icon': Icons.home_repair_service},
          {'title': 'احجز خدمة', 'icon': Icons.calendar_month},
          {'title': 'طلباتي', 'icon': Icons.assignment},
          {'title': 'تقييماتي', 'icon': Icons.star},
        ];

      case Role.craftsman:
        return [
          {'title': 'طلبات الخدمة', 'icon': Icons.assignment},
          {'title': 'المواعيد', 'icon': Icons.event},
          {'title': 'خدماتي', 'icon': Icons.handyman},
          {'title': 'أرباحي', 'icon': Icons.account_balance_wallet},
          {'title': 'تقييمات العملاء', 'icon': Icons.star},
        ];

      case Role.admin:
        return [
          {'title': 'إدارة العملاء', 'icon': Icons.people},
          {'title': 'إدارة الحرفيين', 'icon': Icons.engineering},
          {'title': 'إدارة الطلبات', 'icon': Icons.list_alt},
          {'title': 'الشكاوى', 'icon': Icons.report_problem},
          {'title': 'إحصائيات التطبيق', 'icon': Icons.bar_chart},
        ];

      default:
        return [];
    }
  }

  String get roleTitle {
    switch (role) {
      case Role.customer:
        return 'العميل';
      case Role.craftsman:
        return 'الحرفي';
      case Role.admin:
        return 'مدير النظام';
      default:
        return 'مستخدم';
    }
  }

  void showMessage(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title - قريباً'),
        backgroundColor: dark,
      ),
    );
  }

  void openFeature(BuildContext context, IconData featureIcon, String title) {
    if (featureIcon == Icons.calendar_month && role == Role.customer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateBookingScreen(customerName: fullName),
        ),
      );
      return;
    }

    if (featureIcon == Icons.assignment) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingsScreen(
            role: role,
            customerName: fullName,
          ),
        ),
      );
      return;
    }

    showMessage(context, title);
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handyman,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'حِرفي',
                style: TextStyle(
                  color: dark,
                  fontWeight: FontWeight.bold,
                  fontSize: 23,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout, color: dark),
              tooltip: 'تسجيل الخروج',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section
                Text(
                  'أهلاً، $fullName 👋',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  roleTitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 22),

                if (role == Role.customer) ...[
                  // Orange banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'كل خدمات بيتك بمكان واحد!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'اختار الخدمة، وإحنا بنساعدك تلاقي الحرفي المناسب.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const TextField(
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              hintText: 'شو الخدمة اللي بتدور عليها؟',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: orange,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 27),

                  const Text(
                    'استكشف الخدمات',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Service categories
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.55,
                    children: [
                      _serviceCard(
                        context,
                        'كهربائي',
                        Icons.electrical_services,
                      ),
                      _serviceCard(
                        context,
                        'سباك',
                        Icons.plumbing,
                      ),
                      _serviceCard(
                        context,
                        'نجار',
                        Icons.carpenter,
                      ),
                      _serviceCard(
                        context,
                        'دهان',
                        Icons.format_paint,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                ],

                Text(
                  role == Role.customer
                      ? 'خدماتك'
                      : 'لوحة التحكم',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 14),

                // Role features
                ...features.map(
                  (feature) => Container(
                    margin: const EdgeInsets.only(bottom: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.035),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      leading: Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          feature['icon'] as IconData,
                          color: orange,
                        ),
                      ),
                      title: Text(
                        feature['title'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: dark,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () => openFeature(
                        context,
                        feature['icon'] as IconData,
                        feature['title'] as String,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
  selectedIndex: 0,
  backgroundColor: Colors.white,
  indicatorColor: const Color(0xFFFF6B35).withValues(alpha: 0.15),
  onDestinationSelected: (index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            fullName: fullName,
            role: role,
          ),
        ),
      );
    }
  },
  destinations: const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(
        Icons.home,
        color: Color(0xFFFF6B35),
      ),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      label: 'حسابي',
    ),
  ],
),
      ),
    );
  }

  Widget _serviceCard(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return InkWell(
      onTap: () => showMessage(context, title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: orange, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: dark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
