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
