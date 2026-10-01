const admin = require('firebase-admin');
const serviceAccount = require('./new_project_service_account.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function cleanupAndUnify() {
  console.log('🧹 [1/4] Cleaning phone_directory collection...');
  const pdSnapshot = await db.collection('phone_directory').get();
  const validKeys = new Set(['+249146979833', '+249912209596', '+249123456789', '+249123456788']);
  
  const batch = db.batch();
  let deletedCount = 0;

  for (const doc of pdSnapshot.docs) {
    if (!validKeys.has(doc.id)) {
      console.log(`Deleting redundant phone_directory doc: ${doc.id}`);
      batch.delete(doc.ref);
      deletedCount++;
    }
  }

  // Ensure Admin 1 clean entry in phone_directory
  batch.set(db.collection('phone_directory').doc('+249146979833'), {
    uid: 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
    name: 'المشرف الأساسي',
    phone: '+249146979833',
    role: 'admin',
    status: 'active',
    accountId: '111111111111',
    email: 'admin_01146979833@mahameek.admin.com',
    isPrimary: true,
    passwordHash: '14756e3e38ec020dc701f8c86784e7c120b56c51c295dd7bd26090018f7b8f7f',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Ensure Admin 2 clean entry in phone_directory
  batch.set(db.collection('phone_directory').doc('+249912209596'), {
    uid: 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2',
    name: 'صاحب التطبيق',
    phone: '+249912209596',
    role: 'admin',
    status: 'active',
    accountId: '222222222222',
    email: 'admin_912209596@mahameek.admin.com',
    isPrimary: true,
    passwordHash: '14756e3e38ec020dc701f8c86784e7c120b56c51c295dd7bd26090018f7b8f7f',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Ensure Client Noor has clean +249123456789 entry
  batch.set(db.collection('phone_directory').doc('+249123456789'), {
    uid: '4CGTWCTX4MeBUoyheasWCDb5JNt2',
    name: 'noor nady saber',
    phone: '+249123456789',
    role: 'client',
    status: 'active',
    accountId: '352083813367',
    email: '249123456789@mahameek.client.com',
    isPrimary: false,
    passwordHash: '14756e3e38ec020dc701f8c86784e7c120b56c51c295dd7bd26090018f7b8f7f',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();
  console.log(`✅ phone_directory cleaned! Deleted ${deletedCount} redundant docs.`);

  console.log('🆔 [2/4] Unifying Account IDs in Firestore...');
  const syncBatch = db.batch();

  // Admin 1 (HEsYK0F5TGMFCZtKE7qUq0kFfqQ2)
  syncBatch.set(db.collection('admins').doc('HEsYK0F5TGMFCZtKE7qUq0kFfqQ2'), {
    accountId: '111111111111',
    phone: '+249146979833',
  }, { merge: true });
  syncBatch.set(db.collection('users').doc('HEsYK0F5TGMFCZtKE7qUq0kFfqQ2'), {
    accountId: '111111111111',
    phone: '+249146979833',
  }, { merge: true });
  syncBatch.set(db.collection('account_ids').doc('111111111111'), {
    uid: 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
    role: 'admin',
  }, { merge: true });
  syncBatch.set(db.collection('account_ids').doc('11111111111'), {
    uid: 'HEsYK0F5TGMFCZtKE7qUq0kFfqQ2',
    role: 'admin',
  }, { merge: true });

  // Admin 2 (VQ5M7vEKaubtw3H3tOtDMHgB4yg2)
  syncBatch.set(db.collection('admins').doc('VQ5M7vEKaubtw3H3tOtDMHgB4yg2'), {
    accountId: '222222222222',
    phone: '+249912209596',
  }, { merge: true });
  syncBatch.set(db.collection('users').doc('VQ5M7vEKaubtw3H3tOtDMHgB4yg2'), {
    accountId: '222222222222',
    phone: '+249912209596',
  }, { merge: true });
  syncBatch.set(db.collection('account_ids').doc('222222222222'), {
    uid: 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2',
    role: 'admin',
  }, { merge: true });

  // Client Noor (4CGTWCTX4MeBUoyheasWCDb5JNt2)
  syncBatch.set(db.collection('users').doc('4CGTWCTX4MeBUoyheasWCDb5JNt2'), {
    accountId: '352083813367',
    phone: '+249123456789',
  }, { merge: true });
  syncBatch.set(db.collection('account_ids').doc('352083813367'), {
    uid: '4CGTWCTX4MeBUoyheasWCDb5JNt2',
    role: 'client',
  }, { merge: true });

  await syncBatch.commit();
  console.log('✅ Account IDs unified successfully!');

  // Check current phone_directory docs
  const finalPd = await db.collection('phone_directory').get();
  console.log('Final phone_directory entries:', finalPd.docs.map(d => `${d.id} -> ${d.data().name} (${d.data().accountId})`));
}

cleanupAndUnify().then(() => {
  console.log('🎉 Cleanup and unification complete!');
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
