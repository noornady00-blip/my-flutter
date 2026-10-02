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
  return crypto.createHash('sha512').update(password).digest('hex');
}

async function fullWipeAndSeed() {
  console.log('========================================================');
  console.log('🧹 1. بدء حذف جميع الحسابات في Firebase Authentication بلا استثناء...');
  console.log('========================================================');

  let totalDeletedAuth = 0;
  let pageToken;
  do {
    const listResult = await auth.listUsers(1000, pageToken);
    const uids = listResult.users.map(u => u.uid);
    if (uids.length > 0) {
      const deleteResult = await auth.deleteUsers(uids);
      totalDeletedAuth += deleteResult.successCount;
      console.log(`تم حذف دفعة من ${deleteResult.successCount} حساب.`);
    }
    pageToken = listResult.pageToken;
  } while (pageToken);

  console.log(`✅ تم حذف جميع حسابات Auth بنجاح! الإجمالي: ${totalDeletedAuth}`);

  console.log('\n========================================================');
  console.log('🧹 2. حذف كافة المجموعات والمستندات والرسائل من Firestore...');
  console.log('========================================================');

  // First delete chats and all messages subcollections
  try {
    const chatsSnap = await db.collection('chats').get();
    console.log(`جارٍ حذف ${chatsSnap.size} محادثة مع رسائلها الفرعية...`);
    for (const chatDoc of chatsSnap.docs) {
      const msgsSnap = await chatDoc.ref.collection('messages').get();
      if (msgsSnap.size > 0) {
        const b = db.batch();
        msgsSnap.docs.forEach(d => b.delete(d.ref));
        await b.commit();
      }
      await chatDoc.ref.delete();
    }
    console.log('✅ تم تفريغ مجموعة chats ورسائلها بالكامل.');
  } catch (e) {
    console.log(`ملاحظة أثناء حذف chats: ${e.message}`);
  }

  const collections = [
    'users',
    'admins',
    'lawyers',
    'clients',
    'phone_directory',
    'account_ids',
    'admin_tokens',
    'admin_notifications',
    'admin_fcm_tokens',
    'support_messages',
    'password_resets',
    'lawyer_requests',
    'notifications',
    'consultations',
    'cases',
    'reviews'
  ];

  for (const colName of collections) {
    try {
      const snap = await db.collection(colName).get();
      if (snap.size > 0) {
        const docs = snap.docs;
        for (let i = 0; i < docs.length; i += 400) {
          const chunk = docs.slice(i, i + 400);
          const batch = db.batch();
          chunk.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
        }
        console.log(`تم تفريغ [${colName}] (${snap.size} مستند).`);
      } else {
        console.log(`[${colName}] فارغ.`);
      }
    } catch (e) {
      console.log(`تخطي [${colName}]: ${e.message}`);
    }
  }

  console.log('\n========================================================');
  console.log('👑 3. إنشاء الحسابين الأساسيين للمشرفين...');
  console.log('========================================================');

  // Admin 1 (+249146979833)
  const admin1Uid = 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2';
  const admin1Phone = '+249146979833';
  const admin1Email = 'admin_01146979833@mahameek.admin.com';
  const admin1Pass = '123456';
  const admin1AccountId = '111111111111';

  // Admin 2 (+249912209596)
  const admin2Uid = 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2';
  const admin2Phone = '+249912209596';
  const admin2Email = 'admin_912209596@mahameek.admin.com';
  const admin2Pass = '123456';
  const admin2AccountId = '222222222222';

  console.log(`إنشاء المشرف 1: ${admin1Email} (${admin1Phone})...`);
  await auth.createUser({
    uid: admin1Uid,
    email: admin1Email,
    password: admin1Pass,
    displayName: 'المشرف الأساسي',
    emailVerified: true
  });
  await auth.setCustomUserClaims(admin1Uid, { admin: true, isPrimary: true });

  console.log(`إنشاء المشرف 2: ${admin2Email} (${admin2Phone})...`);
  await auth.createUser({
    uid: admin2Uid,
    email: admin2Email,
    password: admin2Pass,
    displayName: 'صاحب التطبيق',
    emailVerified: true
  });
  await auth.setCustomUserClaims(admin2Uid, { admin: true, isPrimary: true });

  const admin1Data = {
    uid: admin1Uid,
    name: 'المشرف الأساسي',
    phone: admin1Phone,
    role: 'admin',
    email: admin1Email,
    accountId: admin1AccountId,
    passwordHash: hashPassword(admin1Pass),
    status: 'active',
    isPrimary: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  const admin2Data = {
    uid: admin2Uid,
    name: 'صاحب التطبيق',
    phone: admin2Phone,
    role: 'admin',
    email: admin2Email,
    accountId: admin2AccountId,
    passwordHash: hashPassword(admin2Pass),
    status: 'active',
    isPrimary: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  // Set Firestore docs
  await db.collection('users').doc(admin1Uid).set(admin1Data);
  await db.collection('admins').doc(admin1Uid).set(admin1Data);

  await db.collection('users').doc(admin2Uid).set(admin2Data);
  await db.collection('admins').doc(admin2Uid).set(admin2Data);

  // Set phone_directory ONLY with the exact single phone format requested
  await db.collection('phone_directory').doc(admin1Phone).set(admin1Data);
  await db.collection('phone_directory').doc(admin2Phone).set(admin2Data);

  // Set account_ids entries
  const batch = db.batch();
  batch.set(db.collection('account_ids').doc('11111111111'), { uid: admin1Uid, role: 'admin', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  batch.set(db.collection('account_ids').doc('111111111111'), { uid: admin1Uid, role: 'admin', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  batch.set(db.collection('account_ids').doc('222222222222'), { uid: admin2Uid, role: 'admin', createdAt: admin.firestore.FieldValue.serverTimestamp() });
  await batch.commit();

  console.log('\n========================================================');
  console.log('🎉 تم بنجاح تام! الحسابان الأساسيان فقط موجودان الآن:');
  console.log(`1. المشرف 1: هاتف: ${admin1Phone} | باسورد: ${admin1Pass} | AccountID: 111111111111`);
  console.log(`2. المشرف 2: هاتف: ${admin2Phone} | باسورد: ${admin2Pass} | AccountID: 222222222222`);
  console.log('وفي phone_directory يوجد فقط المستندان المحددان بالضبط!');
  console.log('========================================================');
}

fullWipeAndSeed().catch(console.error);
