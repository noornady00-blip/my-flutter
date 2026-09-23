const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const URGENT_CHANNEL_ID = "mahameek_urgent_alerts_v4";

/**
 * إرسال إشعار فوري لحساب المشرف حتى لو كان التطبيق مغلقاً
 * عند وصول طلب جديد لاستعادة كلمة المرور
 */
exports.onPasswordResetCreated = functions.firestore
  .document("password_resets/{ticketId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const phone = data.phone || "غير محدد";

    const payload = {
      topic: "admin_notifications",
      notification: {
        title: "طلب استعادة كلمة المرور",
        body: `رقم الهاتف: ${phone}`,
      },
      data: {
        type: "password_reset",
        ticketId: context.params.ticketId,
        phone: String(phone),
      },
      android: {
        priority: "high",
        notification: {
          channelId: URGENT_CHANNEL_ID,
          sound: "default",
          priority: "max",
          visibility: "public",
          icon: "ic_stat_mahameek",
          color: "#0B2A5B",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("Successfully sent reset alert to admin:", response);
      return response;
    } catch (error) {
      console.error("Error sending push notification for password reset:", error);
      return null;
    }
  });

/**
 * إرسال إشعار فوري لحساب المشرف حتى لو كان التطبيق مغلقاً
 * عند وصول رسالة تواصل أو دعم فني جديدة
 */
exports.onSupportMessageCreated = functions.firestore
  .document("support_messages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const name = data.name || "مستخدم المنصة";
    const body = data.message || "وصلتك رسالة تواصل جديدة";
    const phone = data.phone || "";

    const payload = {
      topic: "admin_notifications",
      notification: {
        title: `رسالة تواصل جديدة من ${name}`,
        body: String(body),
      },
      data: {
        type: "support_message",
        messageId: context.params.messageId,
        name: String(name),
        phone: String(phone),
      },
      android: {
        priority: "high",
        notification: {
          channelId: URGENT_CHANNEL_ID,
          sound: "default",
          priority: "max",
          visibility: "public",
          icon: "ic_stat_mahameek",
          color: "#0B2A5B",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("Successfully sent support message alert to admin:", response);
      return response;
    } catch (error) {
      console.error("Error sending push notification for support message:", error);
      return null;
    }
  });

/**
 * إرسال إشعار فوري لحساب المشرف حتى لو كان التطبيق مغلقاً
 * عند تسجيل أو طلب انضمام محامٍ جديد
 */
exports.onLawyerCreated = functions.firestore
  .document("lawyers/{lawyerId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const name = data.name || "محامٍ جديد";
    const city = data.city || "غير محددة";
    const phone = data.phone || "";

    const payload = {
      topic: "admin_notifications",
      notification: {
        title: "طلب انضمام محام جديد",
        body: `طلب انضمام جديد من المحامي: ${name} (${city})`,
      },
      data: {
        type: "lawyer_registration",
        lawyerId: context.params.lawyerId,
        name: String(name),
        phone: String(phone),
        city: String(city),
      },
      android: {
        priority: "high",
        notification: {
          channelId: URGENT_CHANNEL_ID,
          sound: "default",
          priority: "max",
          visibility: "public",
          icon: "ic_stat_mahameek",
          color: "#0B2A5B",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("Successfully sent lawyer alert to admin:", response);
      return response;
    } catch (error) {
      console.error("Error sending push notification for new lawyer:", error);
      return null;
    }
  });

/**
 * تحديث كلمة المرور في Firebase Auth مباشرة عند قيام الأدمن بإعادة تعيينها
 */
exports.onUserPasswordReset = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    const afterData = change.after.exists ? change.after.data() : null;
    const beforeData = change.before.exists ? change.before.data() : null;

    if (!afterData) return null;

    const newResetPw = afterData.adminResetPassword;
    const oldResetPw = beforeData ? beforeData.adminResetPassword : null;

    if (newResetPw && newResetPw !== oldResetPw) {
      const uid = context.params.userId;
      const cleanPw = String(newResetPw).trim();
      const fbPassword = cleanPw.length >= 6 ? cleanPw : cleanPw.padRight(6, "0");

      try {
        await admin.auth().updateUser(uid, {
          password: fbPassword,
        });
        console.log(`Successfully updated Firebase Auth password for user ${uid}`);
      } catch (err) {
        console.error(`Failed to update Firebase Auth password for ${uid}:`, err);
      }
    }
    return null;
  });

/**
 * تحديث كلمة المرور لحساب المحامي في Firebase Auth مباشرة
 */
exports.onLawyerPasswordReset = functions.firestore
  .document("lawyers/{lawyerId}")
  .onWrite(async (change, context) => {
    const afterData = change.after.exists ? change.after.data() : null;
    const beforeData = change.before.exists ? change.before.data() : null;

    if (!afterData) return null;

    const newResetPw = afterData.adminResetPassword;
    const oldResetPw = beforeData ? beforeData.adminResetPassword : null;

    if (newResetPw && newResetPw !== oldResetPw) {
      const uid = context.params.lawyerId;
      const cleanPw = String(newResetPw).trim();
      const fbPassword = cleanPw.length >= 6 ? cleanPw : cleanPw.padRight(6, "0");

      try {
        await admin.auth().updateUser(uid, {
          password: fbPassword,
        });
        console.log(`Successfully updated Firebase Auth password for lawyer ${uid}`);
      } catch (err) {
        console.error(`Failed to update Firebase Auth password for lawyer ${uid}:`, err);
      }
    }
    return null;
  });

/**
 * حذف الحساب بالكامل من Firebase Authentication عند حذف المستخدم من Firestore
 */
exports.onUserDeleted = functions.firestore
  .document("users/{userId}")
  .onDelete(async (snap, context) => {
    const uid = context.params.userId;
    try {
      await admin.auth().deleteUser(uid);
      console.log(`Successfully deleted Auth user for user ${uid}`);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        console.log(`Auth user ${uid} was already deleted or does not exist.`);
      } else {
        console.error(`Failed to delete Auth user ${uid}:`, err);
      }
    }
  });

/**
 * حذف الحساب بالكامل من Firebase Authentication عند حذف المحامي من Firestore
 */
exports.onLawyerDeleted = functions.firestore
  .document("lawyers/{lawyerId}")
  .onDelete(async (snap, context) => {
    const uid = context.params.lawyerId;
    try {
      await admin.auth().deleteUser(uid);
      console.log(`Successfully deleted Auth user for lawyer ${uid}`);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        console.log(`Auth user ${uid} was already deleted or does not exist.`);
      } else {
        console.error(`Failed to delete Auth user ${uid}:`, err);
      }
    }
  });

/**
 * ✅ Callable Function — حذف حساب المستخدم نهائياً من Firebase Auth
 * يستخدم Admin SDK الذي يحذف الحساب بدون أي قيود (no requires-recent-login).
 * المستخدم لا يقدر يحذف إلا حسابه الخاص فقط.
 */
exports.deleteMyAccount = functions.https.onCall(async (data, context) => {
  // يجب أن يكون المستخدم مسجلاً الدخول
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "يجب تسجيل الدخول أولاً لتنفيذ هذا الإجراء."
    );
  }

  const callerUid = context.auth.uid;

  // السماح فقط بحذف الحساب الخاص أو حساب آخر إذا كان المستدعي مشرفاً
  const targetUid = (data && data.uid) ? data.uid : callerUid;
  if (targetUid !== callerUid) {
    try {
      const adminDoc = await admin.firestore().collection("admins").doc(callerUid).get();
      const userDoc = await admin.firestore().collection("users").doc(callerUid).get();
      const isAdmin =
        adminDoc.exists ||
        (userDoc.exists && userDoc.data() && userDoc.data().role === "admin");
      if (!isAdmin) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "غير مصرح لك بحذف حساب مستخدم آخر."
        );
      }
    } catch (err) {
      if (err instanceof functions.https.HttpsError) throw err;
      throw new functions.https.HttpsError("internal", "تعذر التحقق من صلاحيات المستخدم.");
    }
  }

  try {
    await admin.auth().deleteUser(targetUid);
    console.log(`✅ [deleteMyAccount] Auth user ${targetUid} deleted by ${callerUid}`);
    return { success: true };
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      console.log(`[deleteMyAccount] User ${targetUid} not found in Auth (already deleted).`);
      return { success: true };
    }
    console.error(`[deleteMyAccount] Failed to delete auth user ${targetUid}:`, err);
    throw new functions.https.HttpsError("internal", `فشل حذف الحساب: ${err.message}`);
  }
});
