
// seed.js
// Hirafi - Firebase initial data seeder
// Development / testing only.

const { initializeApp, cert, getApp, deleteApp } =
  require('firebase-admin/app');

const { getFirestore, FieldValue } =
  require('firebase-admin/firestore');

const { getAuth } =
  require('firebase-admin/auth');

const serviceAccount = require('./serviceAccountKey.json');

// Prevent seeding the wrong Firebase project.
const EXPECTED_PROJECT_ID = 'hirafiproject-f7fa3';

if (serviceAccount.project_id !== EXPECTED_PROJECT_ID) {
  throw new Error(
    `Wrong Firebase project! Expected ${EXPECTED_PROJECT_ID}, ` +
    `received ${serviceAccount.project_id}`
  );
}

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const auth = getAuth();


const serverTimestamp = () => FieldValue.serverTimestamp();
const PASSWORD = 'Hirafi@123456';

// --------------------------------------------------
// Categories
// --------------------------------------------------

const categories = [
  { id: 'plumbing', nameAr: 'سباكة', nameEn: 'Plumbing', icon: 'plumbing' },
  { id: 'electrical', nameAr: 'كهرباء', nameEn: 'Electrical', icon: 'electrical_services' },
  { id: 'carpentry', nameAr: 'نجارة', nameEn: 'Carpentry', icon: 'carpenter' },
  { id: 'painting', nameAr: 'دهان', nameEn: 'Painting', icon: 'format_paint' },
  { id: 'ac_repair', nameAr: 'صيانة تكييف', nameEn: 'AC repair', icon: 'ac_unit' },
  { id: 'cleaning', nameAr: 'تنظيف', nameEn: 'Cleaning', icon: 'cleaning_services' },
];

// --------------------------------------------------
// Weekly schedule
// --------------------------------------------------

const weekly = (fridayOff = true) => ({
  sat: { enabled: true, startHour: 9, endHour: 17 },
  sun: { enabled: true, startHour: 9, endHour: 17 },
  mon: { enabled: true, startHour: 9, endHour: 17 },
  tue: { enabled: true, startHour: 9, endHour: 17 },
  wed: { enabled: true, startHour: 9, endHour: 17 },
  thu: { enabled: true, startHour: 9, endHour: 17 },
  fri: { enabled: !fridayOff, startHour: 9, endHour: 17 },
});

// --------------------------------------------------
// Test accounts
// --------------------------------------------------

const admins = [
  {
    email: 'admin@hirafi.com',
    name: 'مدير النظام',
    phone: '0790000000',
    city: 'irbid',
  },
];

const customers = [
  {
    email: 'customer1@hirafi.com',
    name: 'سامر العلي',
    phone: '0791111111',
    city: 'irbid',
  },
  {
    email: 'customer2@hirafi.com',
    name: 'ليلى حداد',
    phone: '0792222222',
    city: 'amman',
  },
];

const craftsmen = [
  {
    email: 'plumber1@hirafi.com',
    name: 'أبو خالد',
    phone: '0793333333',
    city: 'irbid',
    nationalId: '9900000001',
    categoryIds: ['plumbing'],
    services: ['تمديد مواسير', 'صيانة تسريب'],
    experienceYears: 12,
    pricePerHour: 8,
    priceMax: 15,
    bio: 'سبّاك خبرة 12 سنة بإربد',
    status: 'approved',
  },
  {
    email: 'electric1@hirafi.com',
    name: 'محمد الزعبي',
    phone: '0794444444',
    city: 'irbid',
    nationalId: '9900000002',
    categoryIds: ['electrical'],
    services: ['تمديدات كهرباء', 'لوحات توزيع'],
    experienceYears: 8,
    pricePerHour: 10,
    priceMax: 18,
    bio: 'فني كهرباء مرخّص',
    status: 'approved',
  },
  {
    email: 'carpenter1@hirafi.com',
    name: 'يوسف النجار',
    phone: '0795555555',
    city: 'amman',
    nationalId: '9900000003',
    categoryIds: ['carpentry', 'painting'],
    services: ['تفصيل خزائن', 'دهان'],
    experienceYears: 15,
    pricePerHour: 12,
    priceMax: 20,
    bio: 'نجارة وديكور',
    status: 'approved',
  },
  {
    email: 'pending1@hirafi.com',
    name: 'حرفي تحت المراجعة',
    phone: '0796666666',
    city: 'zarqa',
    nationalId: '9900000004',
    categoryIds: ['ac_repair'],
    services: ['صيانة مكيفات'],
    experienceYears: 3,
    pricePerHour: 7,
    bio: 'بانتظار اعتماد الأدمن',
    status: 'pending',
  },
];

// --------------------------------------------------
// Helpers
// --------------------------------------------------

// Preserve original creation timestamps when seeding again.
async function getExistingTimestamp(collection, documentId, field) {
  const snapshot = await db.collection(collection).doc(documentId).get();

  if (snapshot.exists && snapshot.data()[field]) {
    return snapshot.data()[field];
  }

  return serverTimestamp();
}

// Create Auth account if it does not already exist.
// Existing account passwords are NOT changed.
async function ensureAuthUser(email, displayName) {
  try {
    const existingUser = await auth.getUserByEmail(email);

    return {
      uid: existingUser.uid,
      created: false,
    };
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }

    const newUser = await auth.createUser({
      email,
      password: PASSWORD,
      displayName,
    });

    return {
      uid: newUser.uid,
      created: true,
    };
  }
}

// --------------------------------------------------
// Users
// --------------------------------------------------


async function seedUser(user, role) {
  const authUser = await ensureAuthUser(user.email, user.name);
  const uid = authUser.uid;

  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();

  if (userDoc.exists) {
    console.log(
      `Existing Firestore user preserved: ${user.email} | ${uid}`
    );
    return uid;
  }

  if (!authUser.created) {
  throw new Error(
    `Safety check failed: Auth user exists but Firestore document is missing: ${user.email}. Manual review required.`
  );
}

  await userRef.set({
    name: user.name,
    email: user.email,
    phone: user.phone,
    city: user.city,
    role,
    status: 'active',
    language: 'ar',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  console.log(
    `New ${role}: ${user.email} | ${uid} | Auth account created or found`
  );

  return uid;
}


// --------------------------------------------------
// Main seeder
// --------------------------------------------------

async function main() {
  console.log('Starting Hirafi Firebase seeder...');

  console.log('Project:', EXPECTED_PROJECT_ID);

  
  // Settings
  const settingsRef = db.collection('settings').doc('app');
  const settingsDoc = await settingsRef.get();

  if (!settingsDoc.exists) {
    await settingsRef.set({
      inactivityTimeoutMinutes: 30,
      maxAdvanceBookingDays: 30,
      maintenanceMode: false,
      updatedAt: serverTimestamp(),
    });
    console.log('settings/app created');
  } else {
    console.log('settings/app already exists - preserved');
  }


  console.log('settings/app OK');

  
  // Categories
  for (const [index, category] of categories.entries()) {
    const categoryRef = db.collection('categories').doc(category.id);
    const categoryDoc = await categoryRef.get();

    if (!categoryDoc.exists) {
      await categoryRef.set({
        nameAr: category.nameAr,
        nameEn: category.nameEn,
        icon: category.icon,
        order: index + 1,
        active: true,
        createdAt: serverTimestamp(),
      });
    }
  }

  console.log(`Categories checked (${categories.length})`);


  console.log(`Categories OK (${categories.length})`);

  // Admin
  for (const user of admins) {
    await seedUser(user, 'admin');
  }

  // Customers
  for (const user of customers) {
    await seedUser(user, 'customer');
  }

 
  // Craftsmen
  for (const craftsman of craftsmen) {
    const uid = await seedUser(craftsman, 'craftsman');

    const approved = craftsman.status === 'approved';

    const craftsmanRef = db.collection('craftsmen').doc(uid);
    const craftsmanDoc = await craftsmanRef.get();

    if (!craftsmanDoc.exists) {
      const createdAt = serverTimestamp();

      const craftsmanData = {
        name: craftsman.name,
        city: craftsman.city,
        bio: craftsman.bio,
        categoryIds: craftsman.categoryIds,
        services: craftsman.services,
        experienceYears: craftsman.experienceYears,
        pricePerHour: craftsman.pricePerHour,

        ...(craftsman.priceMax != null
          ? { priceMax: craftsman.priceMax }
          : {}),

        isAvailableNow: approved,
        weeklySchedule: weekly(true),
        blockedDates: [],

        rating: 0,
        ratingCount: 0,
        ratingSum: 0,

        verificationStatus: craftsman.status,
        approved,

        createdAt,
        updatedAt: serverTimestamp(),
      };

      await craftsmanRef.set(craftsmanData);
      console.log(`New craftsman profile created: ${craftsman.email}`);
    } else {
      console.log(`Existing craftsman profile preserved: ${craftsman.email}`);
    }

    // Verification document
    const verificationRef = db.collection('verifications').doc(uid);
    const verificationDoc = await verificationRef.get();

    if (!verificationDoc.exists) {
      await verificationRef.set({
        nationalId: craftsman.nationalId,
        submittedAt: serverTimestamp(),
      });

      console.log(`New verification created: ${craftsman.email}`);
    } else {
      console.log(`Existing verification preserved: ${craftsman.email}`);
    }

    console.log(
      `Craftsman seeded: ${craftsman.email} (${craftsman.status})`
    );
  }

  console.log('\nHirafi seeding completed successfully.');
  console.log('New test accounts password:', PASSWORD);
  console.log('Existing Auth account passwords were not changed.');
}



// --------------------------------------------------
// Run
// --------------------------------------------------

main()
  .catch((error) => {
    console.error('Seeding failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
  await deleteApp(getApp());
});
