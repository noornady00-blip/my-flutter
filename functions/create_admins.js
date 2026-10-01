const admin = require("firebase-admin");
const serviceAccount = require("./new_project_service_account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function createAdmin(uid, email, phone, name, accountId) {
  try {
    // Delete if already exists
    try {
      await auth.deleteUser(uid);
      console.log(`Deleted existing auth for ${uid}`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') {
        console.error(`Error deleting ${uid}:`, e);
      }
    }

    try {
      const userByEmail = await auth.getUserByEmail(email);
      await auth.deleteUser(userByEmail.uid);
      console.log(`Deleted existing auth by email for ${email}`);
    } catch (e) {
      // ignore
    }

    // Create new Auth User
    const userRecord = await auth.createUser({
      uid: uid,
      email: email,
      password: "123456",
      emailVerified: true,
      displayName: name,
    });
    console.log(`Successfully created Auth user: ${userRecord.uid} with email ${userRecord.email}`);

    // Update Firestore Document for users
    const adminData = {
        uid: uid,
        name: name,
        phone: phone,
        role: 'admin',
        email: email,
        accountId: accountId,
        password: "b123e9e19d217169b981a61188920f9d28638709a5132201684d792b9264271b7f09157ed4321b1c097f7a4abecbfc097724ba6bcac250e04c5535cf97bd0b54", // SHA-512 of 123456
        status: 'active',
        isPrimary: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const batch = db.batch();
    batch.set(db.collection('users').doc(uid), adminData, { merge: true });
    batch.set(db.collection('admins').doc(uid), adminData, { merge: true });
    await batch.commit();
    console.log(`Successfully updated Firestore for ${uid}`);

  } catch (error) {
    console.error(`Error creating admin ${uid}:`, error);
  }
}

async function run() {
  console.log("Creating Admin 1...");
  await createAdmin(
      'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
      'admin_01146979833@mahameek.admin.com',
      '+249146979833',
      'المشرف الأساسي',
      '5642 1902 3114'
  );

  console.log("Creating Admin 2...");
  await createAdmin(
      'VQ5M7vEKaubtw3H3tOtDMHgB4yg2',
      'admin_912209596@mahameek.admin.com',
      '+249912209596',
      'صاحب التطبيق',
      '5642 1902 3115'
  );

  process.exit(0);
}

run();
