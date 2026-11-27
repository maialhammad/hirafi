import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';

import '../core/db_constants.dart';
import '../services/booking_actions.dart';

class BookingsScreen extends StatefulWidget {
  final String role;
  final String customerName;

  const BookingsScreen({
    super.key,
    required this.role,
    required this.customerName,
  });

  @override
  State<BookingsScreen> createState() =>
      _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('يجب تسجيل الدخول'),
        ),
      );
    }

    final baseQuery = FirebaseFirestore.instance
        .collection(Col.bookings);

    Query<Map<String, dynamic>> query;

    if (widget.role == Role.customer) {
      query = baseQuery.where(
        Field.customerUid,
        isEqualTo: user.uid,
      );

      if (_statusFilter != null) {
        query = query.where(
          Field.status,
          isEqualTo: _statusFilter,
        );
      }

      query = query.orderBy(
        Field.startAt,
        descending: true,
      );
    } else if (widget.role == Role.craftsman) {
      query = baseQuery
          .where(
            Field.craftsmanUid,
            isEqualTo: user.uid,
          )
          .orderBy(
            Field.startAt,
            descending: true,
          );
    } else {
      return const Scaffold(
        body: Center(
          child: Text('هذه الشاشة غير متاحة لهذا الدور'),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.role == Role.customer
                ? 'طلباتي'
                : 'طلبات الخدمة',
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String?>(
                initialValue: _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'تصفية حسب الحالة',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('جميع الطلبات'),
                  ),
                  DropdownMenuItem<String?>(
                    value: BookingStatus.pending,
                    child: const Text('قيد الانتظار'),
                  ),
                  DropdownMenuItem<String?>(
                    value: BookingStatus.accepted,
                    child: const Text('مقبول'),
                  ),
                  DropdownMenuItem<String?>(
                    value: BookingStatus.rejected,
                    child: const Text('مرفوض'),
                  ),
                  DropdownMenuItem<String?>(
                    value: BookingStatus.cancelled,
                    child: const Text('ملغي'),
                  ),
                  DropdownMenuItem<String?>(
                    value: BookingStatus.completed,
                    child: const Text('مكتمل'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
            ),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ: ${snapshot.error}',
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final allBookings = snapshot.data?.docs ?? [];

                  final bookings = _statusFilter == null
                      ? allBookings
                      : allBookings.where((doc) {
                          return doc.data()[Field.status] == _statusFilter;
                        }).toList();

                  if (bookings.isEmpty) {
                    return const Center(
                      child: Text('لا توجد طلبات حالياً'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _BookingCard(
                        doc: bookings[index],
                        role: widget.role,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// بيانات الموعد الجديد.
class _RescheduleData {
  final DateTime date;
  final int hour;

  const _RescheduleData(this.date, this.hour);
}

class _BookingCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String role;

  const _BookingCard({
    required this.doc,
    required this.role,
  });

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
        ),
      );
    }
  }

  Future<String?> _askCancelReason(
    BuildContext context,
  ) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إلغاء الحجز'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'سبب الإلغاء (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('رجوع'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  controller.text.trim(),
                );
              },
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<_RescheduleData?> _askReschedule(
    BuildContext context,
  ) async {
    final now = DateTime.now();

    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final date = await showDatePicker(
      context: context,
      initialDate: firstDate.add(
        const Duration(days: 1),
      ),
      firstDate: firstDate,
      lastDate: firstDate.add(
        const Duration(days: 30),
      ),
    );

    if (date == null || !context.mounted) {
      return null;
    }

    int selectedHour = 9;

    return showDialog<_RescheduleData>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('إعادة جدولة الحجز'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'التاريخ: ${dateKey(date)}',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedHour,
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
                        setDialogState(() {
                          selectedHour = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      _RescheduleData(
                        date,
                        selectedHour,
                      ),
                    );
                  },
                  child: const Text('تأكيد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _askReview(
    BuildContext context,
    String bookingId,
  ) async {
    int rating = 5;

    final commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('تقييم الحرفي'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اختاري تقييمك من 1 إلى 5'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration: const InputDecoration(
                      labelText: 'التقييم',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      5,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1} / 5'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          rating = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'تعليق اختياري',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('إرسال التقييم'),
                ),
              ],
            );
          },
        );
      },
    );

    final comment = commentController.text.trim();

    commentController.dispose();

    if (result != true || !context.mounted) return;

    await _run(
      context,
      () => BookingActions.addReview(
        bookingId: bookingId,
        rating: rating,
        comment: comment,
      ),
      'تم إرسال التقييم بنجاح',
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final bookingId = doc.id;

    final status =
        data[Field.status] as String? ?? '';

    final startAt =
        data[Field.startAt] as Timestamp?;

    final hour =
        (data[Field.hour] as num?)?.toInt() ?? 0;

    final duration =
        (data[Field.durationHours] as num?)?.toInt() ?? 0;

    final serviceName =
        data[Field.serviceName] ?? 'خدمة';

    final otherName = role == Role.customer
        ? data[Field.craftsmanName] ?? 'الحرفي'
        : data[Field.customerName] ?? 'العميل';

    final price = data[Field.totalPrice] ?? '-';

    final reviewed = data[Field.reviewed] == true;

    final canComplete = startAt != null &&
        !startAt.toDate().isAfter(DateTime.now());

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serviceName.toString(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              role == Role.customer
                  ? 'الحرفي: $otherName'
                  : 'العميل: $otherName',
            ),

            Text('التاريخ: ${data[Field.date]}'),

            Text('الساعة: $hour:00'),

            Text('المدة: $duration ساعة'),

            Text('السعر الإجمالي: $price دينار'),

            Text('الحالة: $status'),

            if (data[Field.location] != null)
              Text('الموقع: ${data[Field.location]}'),

            if (data[Field.note] != null &&
                data[Field.note].toString().isNotEmpty)
              Text('ملاحظات: ${data[Field.note]}'),

            const Divider(height: 25),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // إجراءات الحرفي.
                if (role == Role.craftsman &&
                    status == BookingStatus.pending)
                  ElevatedButton(
                    onPressed: () => _run(
                      context,
                      () => BookingActions
                          .updateStatusByCraftsman(
                        bookingId: bookingId,
                        newStatus: BookingStatus.accepted,
                      ),
                      'تم قبول الحجز',
                    ),
                    child: const Text('قبول'),
                  ),

                if (role == Role.craftsman &&
                    status == BookingStatus.pending)
                  OutlinedButton(
                    onPressed: () => _run(
                      context,
                      () => BookingActions
                          .updateStatusByCraftsman(
                        bookingId: bookingId,
                        newStatus: BookingStatus.rejected,
                      ),
                      'تم رفض الحجز',
                    ),
                    child: const Text('رفض'),
                  ),

                if (role == Role.craftsman &&
                    status == BookingStatus.accepted)
                  ElevatedButton(
                    onPressed: canComplete
                        ? () => _run(
                              context,
                              () => BookingActions
                                  .updateStatusByCraftsman(
                                bookingId: bookingId,
                                newStatus:
                                    BookingStatus.completed,
                              ),
                              'تم إكمال الحجز',
                            )
                        : null,
                    child: const Text('إكمال الخدمة'),
                  ),

                // إلغاء الحجز من الطرفين.
                if ((role == Role.customer ||
                        role == Role.craftsman) &&
                    (status == BookingStatus.pending ||
                        status == BookingStatus.accepted))
                  OutlinedButton(
                    onPressed: () async {
                      final reason =
                          await _askCancelReason(context);

                      if (reason == null ||
                          !context.mounted) {
                        return;
                      }

                      if (role == Role.customer) {
                        await _run(
                          context,
                          () => BookingActions.cancelByCustomer(
                            bookingId: bookingId,
                            cancelReason: reason,
                          ),
                          'تم إلغاء الحجز',
                        );
                      } else {
                        await _run(
                          context,
                          () => BookingActions
                              .updateStatusByCraftsman(
                            bookingId: bookingId,
                            newStatus: BookingStatus.cancelled,
                            cancelReason: reason,
                          ),
                          'تم إلغاء الحجز',
                        );
                      }
                    },
                    child: const Text('إلغاء'),
                  ),

                // إعادة الجدولة للعميل.
                if (role == Role.customer &&
                    (status == BookingStatus.pending ||
                        status == BookingStatus.accepted))
                  OutlinedButton(
                    onPressed: () async {
                      final result =
                          await _askReschedule(context);

                      if (result == null ||
                          !context.mounted) {
                        return;
                      }

                      final newStartAt = DateTime(
                        result.date.year,
                        result.date.month,
                        result.date.day,
                        result.hour,
                      );

                      await _run(
                        context,
                        () => BookingActions
                            .rescheduleByCustomer(
                          bookingId: bookingId,
                          newDate: result.date,
                          newHour: result.hour,
                          newStartAt: Timestamp.fromDate(
                            newStartAt,
                          ),
                        ),
                        'تم إرسال طلب إعادة الجدولة',
                      );
                    },
                    child: const Text('إعادة الجدولة'),
                  ),

                // التقييم بعد إكمال الخدمة.
                if (role == Role.customer &&
                    status == BookingStatus.completed &&
                    !reviewed)
                  ElevatedButton(
                    onPressed: () {
                      _askReview(context, bookingId);
                    },
                    child: const Text('تقييم الحرفي'),
                  ),

                if (role == Role.customer &&
                    status == BookingStatus.completed &&
                    reviewed)
                  const Chip(
                    label: Text('تم التقييم'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}









