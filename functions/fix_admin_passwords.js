const admin = require('firebase-admin');
const path = require('path');
const crypto = require('crypto');

const serviceAccountPath = path.join(__dirname, 'new_project_service_account.json');
const serviceAccount = require(serviceAccountPath);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'mahameek-30c70'
  });
}

const db = admin.firestore();
const auth = admin.auth();

function hashPassword(password) {
  return crypto.createHash('sha256').update(`mahameek_pwd_salt_2026_${password}_secure`).digest('hex');
}

async function fixAdminPasswords() {
  const password = '123456';
  const hashed = hashPassword(password);
  console.log('Calculated SHA-256 salted hash for 123456:', hashed);

  const admin1Uid = 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2';
  const admin1Phone = '+249146979833';

  const admin2Uid = 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2';
  const admin2Phone = '+249912209596';

  // 1. Update Firebase Auth passwords
  try {
    await auth.updateUser(admin1Uid, { password: password });
    console.log('Updated Auth password for Admin 1');
  } catch (e) {
    console.log('Error updating Auth Admin 1:', e.message);
  }

  try {
    await auth.updateUser(admin2Uid, { password: password });
    console.log('Updated Auth password for Admin 2');
  } catch (e) {
    console.log('Error updating Auth Admin 2:', e.message);
  }

  // 2. Update Firestore documents
  const updateData1 = {
    passwordHash: hashed,
    adminResetPassword: password,
    rawPassword: password,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  const updateData2 = {
    passwordHash: hashed,
    adminResetPassword: password,
    rawPassword: password,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  const batch = db.batch();
  batch.set(db.collection('users').doc(admin1Uid), updateData1, { merge: true });
  batch.set(db.collection('admins').doc(admin1Uid), updateData1, { merge: true });
  batch.set(db.collection('phone_directory').doc(admin1Phone), updateData1, { merge: true });

  batch.set(db.collection('users').doc(admin2Uid), updateData2, { merge: true });
  batch.set(db.collection('admins').doc(admin2Uid), updateData2, { merge: true });
  batch.set(db.collection('phone_directory').doc(admin2Phone), updateData2, { merge: true });

  await batch.commit();
  console.log('Successfully updated Firestore passwordHash and adminResetPassword for both admins!');
}

fixAdminPasswords().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
