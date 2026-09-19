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
        title: "طلب استعادة كلمة المرور 🔑",
        body: `طلب جديد لاستعادة كلمة المرور لرقم: ${phone}`,
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
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
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
        title: `💬 رسالة تواصل جديدة من ${name}`,
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
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
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
        title: "طلب انضمام محامٍ جديد ⚖️",
        body: `تم تقديم طلب انضمام جديد من المحامي: ${name} (${city})`,
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
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
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
