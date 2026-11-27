import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';

import '../core/db_constants.dart';
import 'booking_actions.dart';

class CreateBookingScreen extends StatefulWidget {
  final String customerName;

  const CreateBookingScreen({
    super.key,
    required this.customerName,
  });

  @override
  State<CreateBookingScreen> createState() =>
      _CreateBookingScreenState();
}

class _CreateBookingScreenState
    extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _serviceController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedCraftsmanId;

  DateTime _selectedDate =
      DateTime.now().add(const Duration(days: 1));

  int _selectedHour = 9;
  int _durationHours = 1;

  bool _isLoading = false;

  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>>
      get _categoriesStream {
    return _db
        .collection(Col.categories)
        .where(Field.active, isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      get _craftsmenStream {
    // القاعدة تسمح بالقراءة العامة للحرفيين المعتمدين.
    return _db
        .collection(Col.craftsmen)
        .where(Field.approved, isEqualTo: true)
        .snapshots();
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final lastDate =
        firstDate.add(const Duration(days: 30));

    var initialDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate.add(
        const Duration(days: 1),
      );
    }

    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null ||
        _selectedCraftsmanId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('يجب تسجيل الدخول');
      }

      final categorySnapshot = await _db
          .collection(Col.categories)
          .doc(_selectedCategoryId)
          .get();

      final craftsmanSnapshot = await _db
          .collection(Col.craftsmen)
          .doc(_selectedCraftsmanId)
          .get();

      if (!categorySnapshot.exists ||
          !craftsmanSnapshot.exists) {
        throw Exception('بيانات الخدمة أو الحرفي غير موجودة');
      }

      final category = categorySnapshot.data()!;
      final craftsman = craftsmanSnapshot.data()!;

      // إعادة التحقق من اعتماد الحرفي قبل إنشاء الحجز.
      if (craftsman[Field.approved] != true ||
          craftsman[Field.verificationStatus] !=
              VerificationStatus.approved) {
        throw Exception('هذا الحرفي غير معتمد');
      }

      final categoryIds =
          (craftsman[Field.categoryIds] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();

      if (!categoryIds.contains(_selectedCategoryId)) {
        throw Exception('الحرفي لا يقدم هذه الخدمة');
      }

      final pricePerHour =
          (craftsman[Field.pricePerHour] as num?)
                  ?.toDouble() ??
              0.0;

      if (pricePerHour <= 0) {
        throw Exception('سعر الحرفي غير صحيح');
      }

      if (_selectedHour + _durationHours > 24) {
        throw Exception('مدة الحجز تتجاوز نهاية اليوم');
      }

      final startAtLocal = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedHour,
      );

      if (!startAtLocal.isAfter(DateTime.now())) {
        throw Exception('اختاري موعداً مستقبلياً');
      }

      final serviceName =
          _serviceController.text.trim().isNotEmpty
              ? _serviceController.text.trim()
              : (category[Field.nameAr] ??
                      category[Field.nameEn] ??
                      _selectedCategoryId)
                  .toString();

      final craftsmanName =
          (craftsman[Field.name] ?? '').toString();

      await BookingActions.createBooking(
        customerName: widget.customerName,
        craftsmanUid: _selectedCraftsmanId!,
        craftsmanName: craftsmanName,
        categoryId: _selectedCategoryId!,
        serviceName: serviceName,
        date: _selectedDate,
        hour: _selectedHour,
        durationHours: _durationHours,
        startAt: Timestamp.fromDate(startAtLocal),
        location: _locationController.text.trim(),
        note: _noteController.text.trim(),
        pricePerHour: pricePerHour,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب الحجز بنجاح'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء الحجز: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حجز خدمة'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختيار الخدمة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                // التصنيفات.
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoriesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'تعذر تحميل التصنيفات',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }

                    final docs = [
                      ...snapshot.data!.docs
                    ]..sort((a, b) {
                        final aOrder =
                            (a.data()[Field.order] as num?)
                                    ?.toInt() ??
                                0;
                        final bOrder =
                            (b.data()[Field.order] as num?)
                                    ?.toInt() ??
                                0;

                        return aOrder.compareTo(bOrder);
                      });

                    final ids =
                        docs.map((doc) => doc.id).toSet();

                    final selected =
                        ids.contains(_selectedCategoryId)
                            ? _selectedCategoryId
                            : null;

                    return DropdownButtonFormField<String>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      items: docs.map((doc) {
                        final data = doc.data();

                        final name =
                            data[Field.nameAr] ??
                                data[Field.nameEn] ??
                                doc.id;

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(name.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedCraftsmanId = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'اختاري التصنيف';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 18),

                // الحرفيون المعتمدون.
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _craftsmenStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'تعذر تحميل الحرفيين',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }

                    final docs = snapshot.data!.docs.where(
                      (doc) {
                        final data = doc.data();

                        if (data[Field.approved] != true ||
                            data[Field.verificationStatus] !=
                                VerificationStatus.approved) {
                          return false;
                        }

                        final categories =
                            (data[Field.categoryIds]
                                        as List<dynamic>? ??
                                    [])
                                .map((e) => e.toString())
                                .toList();

                        if (_selectedCategoryId != null &&
                            !categories.contains(
                              _selectedCategoryId,
                            )) {
                          return false;
                        }

                        return true;
                      },
                    ).toList();

                    final ids =
                        docs.map((doc) => doc.id).toSet();

                    final selected =
                        ids.contains(_selectedCraftsmanId)
                            ? _selectedCraftsmanId
                            : null;

                    return DropdownButtonFormField<String>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الحرفي',
                        border: OutlineInputBorder(),
                      ),
                      items: docs.map((doc) {
                        final data = doc.data();

                        final name =
                            data[Field.name] ?? doc.id;

                        final city =
                            data[Field.city] ?? '';

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            '$name - $city',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCraftsmanId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'اختاري الحرفي';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 18),

                TextFormField(
                  controller: _serviceController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل الخدمة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'موعد الحجز',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text(
                    'التاريخ: ${dateKey(_selectedDate)}',
                  ),
                  trailing: TextButton(
                    onPressed: _pickDate,
                    child: const Text('تغيير'),
                  ),
                ),

                DropdownButtonFormField<int>(
                  initialValue: _selectedHour,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ساعة البداية',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    24,
                    (hour) => DropdownMenuItem<int>(
                      value: hour,
                      child: Text('$hour:00'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedHour = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 18),

                DropdownButtonFormField<int>(
                  initialValue: _durationHours,
                  decoration: const InputDecoration(
                    labelText: 'مدة الخدمة',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    8,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('${index + 1} ساعة'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _durationHours = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 18),

                const Text(
                  'معلومات الموقع',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان تقديم الخدمة',
                    hintText: 'المدينة والمنطقة والعنوان',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'أدخلي موقع تقديم الخدمة';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات إضافية',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 25),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'تأكيد طلب الحجز',
                          style: TextStyle(fontSize: 16),
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
