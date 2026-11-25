// lib/core/db_constants.dart
// Single source of truth for Firestore names. Never type a collection, field or status
// as a raw string anywhere else in the app: use these constants.
// Changing anything here = tell the other two team members first.

abstract class Col {
  static const users = 'users';
  static const craftsmen = 'craftsmen';
  static const verifications = 'verifications';
  static const categories = 'categories';
  static const bookings = 'bookings';
  static const messages = 'messages'; // subcollection of bookings/{id}
  static const bookingSlots = 'bookingSlots';
  static const reviews = 'reviews';
  static const notifications = 'notifications';
  static const complaints = 'complaints';
  static const activityLogs = 'activityLogs';
  static const settings = 'settings'; // single document: settings/app

}

abstract class Role {
  static const customer = 'customer';
  static const craftsman = 'craftsman';
  static const admin = 'admin';
}

abstract class UserStatus {
  static const active = 'active';
  static const suspended = 'suspended';
  static const banned = 'banned';
}

abstract class VerificationStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

abstract class BookingStatus {
  static const pending = 'pending'; // waiting for the craftsman
  static const accepted = 'accepted'; // "Confirmed" in the report
  static const rejected = 'rejected'; // craftsman said no
  static const cancelled = 'cancelled'; // cancelled by customer or craftsman after/before accept
  static const completed = 'completed';

  static const all = [pending, accepted, rejected, cancelled, completed];

  /// statuses that still hold the time slot
  static const holdsSlot = [pending, accepted];
}

abstract class CancelledBy {
  static const customer = 'customer';
  static const craftsman = 'craftsman';
}

abstract class ComplaintStatus {
  static const open = 'open';
  static const inReview = 'in_review';
  static const resolved = 'resolved';
  static const dismissed = 'dismissed';
}

abstract class ComplaintType {
  static const quality = 'quality';
  static const noShow = 'no_show';
  static const price = 'price';
  static const behavior = 'behavior';
  static const other = 'other';
}

abstract class NotifType {
  static const bookingCreated = 'booking_created';
  static const bookingAccepted = 'booking_accepted';
  static const bookingRejected = 'booking_rejected';
  static const bookingCancelled = 'booking_cancelled';
  static const bookingCompleted = 'booking_completed';
  static const bookingRescheduled = 'booking_rescheduled';
  static const verificationApproved = 'verification_approved';
  static const verificationRejected = 'verification_rejected';
  static const reviewReceived = 'review_received';
  static const complaintUpdate = 'complaint_update';
  static const messageReceived = 'message_received';
}

abstract class LogAction {
  static const userRegistered = 'user_registered';
  static const bookingCreated = 'booking_created';
  static const bookingStatusChanged = 'booking_status_changed';
  static const craftsmanApproved = 'craftsman_approved';
  static const craftsmanRejected = 'craftsman_rejected';
  static const userStatusChanged = 'user_status_changed';
  static const categoryChanged = 'category_changed';
  static const complaintUpdated = 'complaint_updated';
  static const reviewAdded = 'review_added';
}

abstract class PaymentMethod {
  static const cash = 'cash';
}

abstract class Lang {
  static const ar = 'ar';
  static const en = 'en';
}

/// Weekday keys used in craftsmen.weeklySchedule (week starts on Saturday in Jordan).
abstract class Weekday {
  static const keys = ['sat', 'sun', 'mon', 'tue', 'wed', 'thu', 'fri'];

  /// DateTime.weekday: Monday = 1 ... Sunday = 7
  static String keyOf(DateTime d) =>
      const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][d.weekday - 1];
}

/// Document id of a bookingSlots lock: craftsmanUid_YYYY-MM-DD_hour
String slotId(String craftsmanUid, String date, int hour) =>
    '${craftsmanUid}_${date}_$hour';

/// 'YYYY-MM-DD' (what we store in bookings.date and bookingSlots.date)
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Jordan governorates: id -> Arabic / English name. Static list, not a collection.
const jordanCities = <String, Map<String, String>>{
  'amman': {'ar': 'عمّان', 'en': 'Amman'},
  'irbid': {'ar': 'إربد', 'en': 'Irbid'},
  'zarqa': {'ar': 'الزرقاء', 'en': 'Zarqa'},
  'balqa': {'ar': 'البلقاء', 'en': 'Balqa'},
  'madaba': {'ar': 'مأدبا', 'en': 'Madaba'},
  'karak': {'ar': 'الكرك', 'en': 'Karak'},
  'tafilah': {'ar': 'الطفيلة', 'en': 'Tafilah'},
  'maan': {'ar': 'معان', 'en': "Ma'an"},
  'aqaba': {'ar': 'العقبة', 'en': 'Aqaba'},
  'jerash': {'ar': 'جرش', 'en': 'Jerash'},
  'ajloun': {'ar': 'عجلون', 'en': 'Ajloun'},
  'mafraq': {'ar': 'المفرق', 'en': 'Mafraq'},
};
