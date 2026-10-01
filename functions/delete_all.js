const admin = require("firebase-admin");
const serviceAccount = require("./new_project_service_account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

const primaryAdmins = ['HEsYK0F5TGMFCZtKE7qUq0kFfqQ2', 'VQ5M7vEKaubtw3H3tOtDMHgB4yg2'];

async function deleteCollection(collectionPath) {
  const collectionRef = db.collection(collectionPath);
  const snapshot = await collectionRef.get();

  if (snapshot.size === 0) {
    return;
  }

  let batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    if (primaryAdmins.includes(doc.id) && ['users', 'admins', 'lawyers'].includes(doc.ref.parent.id)) {
        console.log(`Skipping primary admin doc: ${doc.ref.path}`);
    } else {
        batch.delete(doc.ref);
        count++;
    }

    if (count === 500) {
        await batch.commit();
        batch = db.batch();
        count = 0;
    }
  }

  if (count > 0) {
      await batch.commit();
  }
}

async function run() {
  try {
    const collections = [
        'users',
        'lawyers',
        'admins',
        'account_ids',
        'admin_fcm_tokens',
        'admin_notifications',
        'admin_tokens',
        'audit_logs',
        'chats',
        'lawyer_requests',
        'one_time_resets',
        'password_resets',
        'phone_directory',
        'support_messages'
    ];

    console.log("Deleting Firestore data...");
    for (const coll of collections) {
        console.log(`Deleting collection: ${coll}`);
        await deleteCollection(coll);
    }
    
    console.log("ALL DATA WIPED SUCCESSFULLY! (Except primary admins)");
    process.exit(0);
  } catch (error) {
    console.error("Error wiping data:", error);
    process.exit(1);
  }
}

run();
