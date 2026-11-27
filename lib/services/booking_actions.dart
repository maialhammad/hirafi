import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';

import '../core/db_constants.dart';

class BookingActions {
  BookingActions._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    return user.uid;
  }

  static DocumentReference<Map<String, dynamic>> _bookingRef(String id) {
    return _db.collection(Col.bookings).doc(id);
  }

  static DocumentReference<Map<String, dynamic>> _slotRef(
    String craftsmanUid,
    String date,
    int hour,
  ) {
    return _db.collection(Col.bookingSlots).doc(
      slotId(craftsmanUid, date, hour),
    );
  }

  // إنشاء حجز جديد وحجز جميع الساعات ضمن transaction واحدة.
  static Future<String> createBooking({
    required String customerName,
    required String craftsmanUid,
    required String craftsmanName,
    required String categoryId,
    required String serviceName,
    required DateTime date,
    required int hour,
    required int durationHours,
    required Timestamp startAt,
    required String location,
    required String note,
    required double pricePerHour,
  }) async {
    final uid = _uid;

    if (craftsmanUid == uid) {
      throw Exception('لا يمكنك الحجز لنفسك');
    }

    if (hour < 0 ||
        durationHours < 1 ||
        durationHours > 8 ||
        hour + durationHours > 24) {
      throw Exception('وقت الحجز أو مدته غير صحيحة');
    }

    if (!startAt.toDate().isAfter(DateTime.now())) {
      throw Exception('يجب اختيار موعد مستقبلي');
    }

    if (pricePerHour <= 0) {
      throw Exception('سعر الحرفي غير صحيح');
    }

    final dateString = dateKey(date);
    final bookingRef = _db.collection(Col.bookings).doc();

    final slots = List.generate(
      durationHours,
      (index) => _slotRef(craftsmanUid, dateString, hour + index),
    );

    return _db.runTransaction<String>((transaction) async {
      // التأكد أن جميع الساعات متاحة قبل إنشاء الحجز.
      for (final slot in slots) {
        final slotSnapshot = await transaction.get(slot);

        if (slotSnapshot.exists) {
          throw Exception('الموعد المحدد محجوز مسبقاً');
        }
      }

      transaction.set(bookingRef, {
        Field.customerUid: uid,
        Field.customerName: customerName,
        Field.craftsmanUid: craftsmanUid,
        Field.craftsmanName: craftsmanName,
        Field.categoryId: categoryId,
        Field.serviceName: serviceName,
        Field.date: dateString,
        Field.hour: hour,
        Field.startAt: startAt,
        Field.durationHours: durationHours,
        Field.pricePerHour: pricePerHour,
        Field.totalPrice: pricePerHour * durationHours,
        Field.location: location,
        Field.note: note,
        Field.paymentMethod: PaymentMethod.cash,
        Field.status: BookingStatus.pending,
        Field.rescheduleCount: 0,
        Field.reviewed: false,
        Field.createdAt: FieldValue.serverTimestamp(),
        Field.updatedAt: FieldValue.serverTimestamp(),
      });

      // إنشاء قفل مستقل لكل ساعة.
      for (int i = 0; i < durationHours; i++) {
        transaction.set(slots[i], {
          Field.craftsmanUid: craftsmanUid,
          Field.date: dateString,
          Field.hour: hour + i,
          Field.bookingId: bookingRef.id,
          Field.createdAt: FieldValue.serverTimestamp(),
        });
      }

      return bookingRef.id;
    });
  }

  // حذف جميع أقفال ساعات الحجز.
  static void _deleteSlots(
    Transaction transaction,
    Map<String, dynamic> booking,
  ) {
    final craftsmanUid = booking[Field.craftsmanUid] as String;
    final date = booking[Field.date] as String;
    final hour = (booking[Field.hour] as num).toInt();
    final duration = (booking[Field.durationHours] as num).toInt();

    for (int i = 0; i < duration; i++) {
      transaction.delete(
        _slotRef(craftsmanUid, date, hour + i),
      );
    }
  }

  // قبول أو رفض أو إلغاء أو إكمال الحجز من طرف الحرفي.
  static Future<void> updateStatusByCraftsman({
    required String bookingId,
    required String newStatus,
    String? cancelReason,
  }) async {
    final uid = _uid;
    final bookingRef = _bookingRef(bookingId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);

      if (!snapshot.exists) {
        throw Exception('الحجز غير موجود');
      }

      final booking = snapshot.data()!;

      if (booking[Field.craftsmanUid] != uid) {
        throw Exception('ليس لديك صلاحية تعديل هذا الحجز');
      }

      final oldStatus = booking[Field.status];

      final updates = <String, dynamic>{
        Field.status: newStatus,
        Field.updatedAt: FieldValue.serverTimestamp(),
      };

      bool releaseSlots = false;

      if (oldStatus == BookingStatus.pending &&
          newStatus == BookingStatus.accepted) {
        updates[Field.acceptedAt] = FieldValue.serverTimestamp();
      } else if (oldStatus == BookingStatus.pending &&
          newStatus == BookingStatus.rejected) {
        releaseSlots = true;
      } else if (oldStatus == BookingStatus.accepted &&
          newStatus == BookingStatus.cancelled) {
        updates[Field.cancelledBy] = CancelledBy.craftsman;
        updates[Field.cancelledAt] = FieldValue.serverTimestamp();

        if (cancelReason != null && cancelReason.trim().isNotEmpty) {
          updates[Field.cancelReason] = cancelReason.trim();
        }

        releaseSlots = true;
      } else if (oldStatus == BookingStatus.accepted &&
          newStatus == BookingStatus.completed) {
        final startAt = booking[Field.startAt] as Timestamp;

        if (startAt.toDate().isAfter(DateTime.now())) {
          throw Exception('لا يمكن إكمال الحجز قبل موعده');
        }

        updates[Field.completedAt] = FieldValue.serverTimestamp();

        // تحرير الساعات بعد completed يحتاج تعديل قاعدة الحذف.
      } else {
        throw Exception('الانتقال بين حالات الحجز غير مسموح');
      }

      transaction.update(bookingRef, updates);

      if (releaseSlots) {
        _deleteSlots(transaction, booking);
      }
    });
  }

  // إلغاء الحجز من طرف العميل.
  static Future<void> cancelByCustomer({
    required String bookingId,
    String? cancelReason,
  }) async {
    final uid = _uid;
    final bookingRef = _bookingRef(bookingId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);

      if (!snapshot.exists) {
        throw Exception('الحجز غير موجود');
      }

      final booking = snapshot.data()!;

      if (booking[Field.customerUid] != uid) {
        throw Exception('ليس لديك صلاحية إلغاء هذا الحجز');
      }

      final status = booking[Field.status];

      if (status != BookingStatus.pending &&
          status != BookingStatus.accepted) {
        throw Exception('لا يمكن إلغاء هذا الحجز');
      }

      final updates = <String, dynamic>{
        Field.status: BookingStatus.cancelled,
        Field.cancelledBy: CancelledBy.customer,
        Field.cancelledAt: FieldValue.serverTimestamp(),
        Field.updatedAt: FieldValue.serverTimestamp(),
      };

      if (cancelReason != null && cancelReason.trim().isNotEmpty) {
        updates[Field.cancelReason] = cancelReason.trim();
      }

      transaction.update(bookingRef, updates);
      _deleteSlots(transaction, booking);
    });
  }

  // إعادة جدولة الحجز من طرف العميل.
  static Future<void> rescheduleByCustomer({
    required String bookingId,
    required DateTime newDate,
    required int newHour,
    required Timestamp newStartAt,
  }) async {
    final uid = _uid;
    final bookingRef = _bookingRef(bookingId);
    final newDateString = dateKey(newDate);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);

      if (!snapshot.exists) {
        throw Exception('الحجز غير موجود');
      }

      final booking = snapshot.data()!;

      if (booking[Field.customerUid] != uid) {
        throw Exception('ليس لديك صلاحية تعديل هذا الحجز');
      }

      final status = booking[Field.status];

      if (status != BookingStatus.pending &&
          status != BookingStatus.accepted) {
        throw Exception('لا يمكن إعادة جدولة هذا الحجز');
      }

      final duration =
          (booking[Field.durationHours] as num).toInt();

      final craftsmanUid =
          booking[Field.craftsmanUid] as String;

      final oldDate = booking[Field.date] as String;

      final oldHour =
          (booking[Field.hour] as num).toInt();

      final oldCount =
          (booking[Field.rescheduleCount] as num).toInt();

      if (newHour < 0 || newHour + duration > 24) {
        throw Exception('وقت الموعد الجديد غير صحيح');
      }

      if (!newStartAt.toDate().isAfter(DateTime.now())) {
        throw Exception('يجب اختيار موعد مستقبلي');
      }

      // تحديد الساعات القديمة والجديدة.
      final oldSlotIds = <String>{};
      final newSlotRefs =
          <String, DocumentReference<Map<String, dynamic>>>{};
      final newSlotHours = <String, int>{};

      for (int i = 0; i < duration; i++) {
        oldSlotIds.add(
          slotId(craftsmanUid, oldDate, oldHour + i),
        );

        final newHourValue = newHour + i;
        final id = slotId(
          craftsmanUid,
          newDateString,
          newHourValue,
        );

        newSlotRefs[id] = _slotRef(
          craftsmanUid,
          newDateString,
          newHourValue,
        );

        newSlotHours[id] = newHourValue;
      }

      final newSlotIds = newSlotRefs.keys.toSet();

      final slotsToDelete = oldSlotIds.difference(newSlotIds);
      final slotsToCreate = newSlotIds.difference(oldSlotIds);

      // التأكد من توفر الساعات الجديدة غير المتداخلة.
      for (final id in slotsToCreate) {
        final snapshot = await transaction.get(newSlotRefs[id]!);

        if (snapshot.exists) {
          throw Exception('الموعد الجديد محجوز مسبقاً');
        }
      }

      // حذف الأقفال القديمة التي لم تعد ضمن الموعد الجديد.
      for (final id in slotsToDelete) {
        transaction.delete(
          _db.collection(Col.bookingSlots).doc(id),
        );
      }

      // إنشاء الأقفال الجديدة.
      for (final id in slotsToCreate) {
        transaction.set(newSlotRefs[id]!, {
          Field.craftsmanUid: craftsmanUid,
          Field.date: newDateString,
          Field.hour: newSlotHours[id],
          Field.bookingId: bookingId,
          Field.createdAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.update(bookingRef, {
        Field.date: newDateString,
        Field.hour: newHour,
        Field.startAt: newStartAt,
        Field.status: BookingStatus.pending,
        Field.rescheduleCount: oldCount + 1,
        Field.acceptedAt: FieldValue.delete(),
        Field.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  // إضافة تقييم وتحديث متوسط تقييم الحرفي ضمن transaction واحدة.
  static Future<void> addReview({
    required String bookingId,
    required int rating,
    String comment = '',
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('التقييم يجب أن يكون بين 1 و5');
    }

    final uid = _uid;
    final bookingRef = _bookingRef(bookingId);
    final reviewRef = _db.collection(Col.reviews).doc(bookingId);

    await _db.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);

      if (!bookingSnapshot.exists) {
        throw Exception('الحجز غير موجود');
      }

      final booking = bookingSnapshot.data()!;

      if (booking[Field.customerUid] != uid) {
        throw Exception('لا يمكنك تقييم هذا الحجز');
      }

      if (booking[Field.status] != BookingStatus.completed) {
        throw Exception('يمكن تقييم الحجوزات المكتملة فقط');
      }

      if (booking[Field.reviewed] == true) {
        throw Exception('تم تقييم هذا الحجز مسبقاً');
      }

      final craftsmanUid =
          booking[Field.craftsmanUid] as String;

      final craftsmanRef =
          _db.collection(Col.craftsmen).doc(craftsmanUid);

      final craftsmanSnapshot =
          await transaction.get(craftsmanRef);

      if (!craftsmanSnapshot.exists) {
        throw Exception('بيانات الحرفي غير موجودة');
      }

      final craftsman = craftsmanSnapshot.data()!;

      final oldCount =
          (craftsman[Field.ratingCount] as num?)?.toInt() ?? 0;

      final oldSum =
          (craftsman[Field.ratingSum] as num?)?.toDouble() ?? 0.0;

      final newCount = oldCount + 1;
      final newSum = oldSum + rating;
      final newRating = newSum / newCount;

      transaction.set(reviewRef, {
        Field.bookingId: bookingId,
        Field.customerUid: uid,
        Field.customerName: booking[Field.customerName],
        Field.craftsmanUid: craftsmanUid,
        Field.rating: rating,
        Field.comment: comment.trim(),
        Field.createdAt: FieldValue.serverTimestamp(),
      });

      transaction.update(bookingRef, {
        Field.reviewed: true,
        Field.updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(craftsmanRef, {
        Field.rating: newRating,
        Field.ratingCount: newCount,
        Field.ratingSum: newSum,
        Field.lastReviewId: bookingId,
        Field.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }
}