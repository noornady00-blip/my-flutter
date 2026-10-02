"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onLawyerCreated = exports.onSupportMessageCreated = exports.onPasswordResetCreated = exports.migrateFixAuthFirestoreMismatch = exports.checkAccountStatus = exports.verifyLoginFailureReason = exports.adminCreateAdminAccount = exports.adminDeleteUserPermanently = exports.adminSetUserDisabled = exports.adminSetUserPassword = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
admin.initializeApp();
const URGENT_CHANNEL_ID = "mahameek_urgent_alerts_v4";
// ============================================================================
// HELPER FUNCTIONS
// ============================================================================
function extractDigits(phone) {
    if (!phone)
        return "";
    let digits = phone.replace(/[^0-9]/g, "");
    if (digits.startsWith("00249"))
        digits = digits.substring(5);
    else if (digits.startsWith("249"))
        digits = digits.substring(3);
    while (digits.startsWith("0"))
        digits = digits.substring(1);
    return digits;
}
function normalizePhone(rawPhone) {
    const digits = extractDigits(rawPhone);
    if (digits.length !== 9) {
        throw new functions.https.HttpsError("invalid-argument", "رقم الهاتف غير صالح، يجب أن يكون 9 أرقام.");
    }
    return `+249${digits}`;
}
function toAuthEmail(normalized) {
    const digits = normalized.replace(/[^0-9]/g, "");
    return `${digits}@mahameek.com`;
}
function isSuperAdminPhone(phone) {
    const digits = extractDigits(phone);
    return digits === "146979833" || digits === "912209596";
}
async function verifyAdminCaller(context) {
    var _a, _b;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول");
    }
    const callerUid = context.auth.uid;
    const adminDoc = await admin.firestore().collection("admins").doc(callerUid).get();
    const userDoc = await admin.firestore().collection("users").doc(callerUid).get();
    const isAdmin = adminDoc.exists || (userDoc.exists && ["admin", "subadmin"].includes((_b = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.role) === null || _b === void 0 ? void 0 : _b.toLowerCase()));
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "صلاحيات غير كافية");
    }
    return callerUid;
}
// ============================================================================
// NEW ACCOUNT MANAGEMENT FUNCTIONS
// ============================================================================
exports.adminSetUserPassword = functions.https.onCall(async (data, context) => {
    var _a;
    await verifyAdminCaller(context);
    const { uid, newPassword } = data;
    if (!uid || !newPassword || newPassword.length < 6) {
        throw new functions.https.HttpsError("invalid-argument", "بيانات غير صالحة");
    }
    // Prevent changing super admin password
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const adminDoc = await admin.firestore().collection("admins").doc(uid).get();
    const lawyerDoc = await admin.firestore().collection("lawyers").doc(uid).get();
    const docData = userDoc.data() || adminDoc.data() || lawyerDoc.data() || {};
    if (isSuperAdminPhone(docData.phone || "")) {
        throw new functions.https.HttpsError("permission-denied", "لا يمكن تعديل حساب المشرف الأساسي");
    }
    const hash = crypto.createHash('sha256').update(newPassword.trim()).digest('hex');
    const now = admin.firestore.FieldValue.serverTimestamp();
    // 1. Update Auth
    const digits = extractDigits(docData.phone || "");
    const authKey = digits.length > 0 ? `MHMK-${digits}-SEC` : "";
    const fbPassword = authKey || newPassword.trim();
    try {
        await admin.auth().updateUser(uid, { password: fbPassword });
    }
    catch (err) {
        if (err.code === "auth/user-not-found") {
            const email = toAuthEmail(docData.phone);
            await admin.auth().createUser({
                uid,
                email,
                password: fbPassword,
            });
        }
        else {
            throw new functions.https.HttpsError("internal", `فشل تحديث Auth: ${err.message}`);
        }
    }
    // 2. Revoke refresh tokens
    await admin.auth().revokeRefreshTokens(uid);
    // 3. Update Firestore Document
    const updateData = {
        passwordHash: hash,
        adminResetPassword: newPassword.trim(),
        passwordChangedAt: now,
    };
    if (userDoc.exists)
        await admin.firestore().collection("users").doc(uid).update(updateData);
    if (adminDoc.exists)
        await admin.firestore().collection("admins").doc(uid).update(updateData);
    if (lawyerDoc.exists)
        await admin.firestore().collection("lawyers").doc(uid).update(updateData);
    // 4. Update Password History
    const historyRef = admin.firestore().collection("passwordHistory").doc(uid);
    const historyDoc = await historyRef.get();
    let entries = historyDoc.exists ? ((_a = historyDoc.data()) === null || _a === void 0 ? void 0 : _a.entries) || [] : [];
    entries.push({ hash, changedAt: new Date().toISOString() });
    if (entries.length > 5)
        entries = entries.slice(entries.length - 5);
    await historyRef.set({ entries });
    return { success: true };
});
exports.adminSetUserDisabled = functions.https.onCall(async (data, context) => {
    await verifyAdminCaller(context);
    const { uid, disabled } = data;
    if (!uid)
        throw new functions.https.HttpsError("invalid-argument", "Missing uid");
    // Prevent disabling super admin
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const adminDoc = await admin.firestore().collection("admins").doc(uid).get();
    const lawyerDoc = await admin.firestore().collection("lawyers").doc(uid).get();
    const docData = userDoc.data() || adminDoc.data() || lawyerDoc.data() || {};
    if (isSuperAdminPhone(docData.phone || "")) {
        throw new functions.https.HttpsError("permission-denied", "لا يمكن إيقاف حساب المشرف الأساسي");
    }
    const status = disabled ? 'suspended' : 'active';
    try {
        await admin.auth().updateUser(uid, { disabled });
    }
    catch (err) {
        if (err.code !== "auth/user-not-found") {
            throw new functions.https.HttpsError("internal", err.message);
        }
    }
    if (disabled) {
        await admin.auth().revokeRefreshTokens(uid);
    }
    const updateData = { status };
    if (userDoc.exists)
        await admin.firestore().collection("users").doc(uid).update(updateData);
    if (adminDoc.exists)
        await admin.firestore().collection("admins").doc(uid).update(updateData);
    if (lawyerDoc.exists)
        await admin.firestore().collection("lawyers").doc(uid).update(updateData);
    return { success: true };
});
exports.adminDeleteUserPermanently = functions.https.onCall(async (data, context) => {
    await verifyAdminCaller(context);
    const { uid } = data;
    if (!uid)
        throw new functions.https.HttpsError("invalid-argument", "Missing uid");
    // Prevent deleting super admin
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const adminDoc = await admin.firestore().collection("admins").doc(uid).get();
    const lawyerDoc = await admin.firestore().collection("lawyers").doc(uid).get();
    const docData = userDoc.data() || adminDoc.data() || lawyerDoc.data() || {};
    if (isSuperAdminPhone(docData.phone || "")) {
        throw new functions.https.HttpsError("permission-denied", "لا يمكن حذف حساب المشرف الأساسي");
    }
    // 1. Delete from Auth
    try {
        await admin.auth().deleteUser(uid);
    }
    catch (err) {
        if (err.code !== "auth/user-not-found") {
            console.error(`Failed to delete auth user ${uid}:`, err);
        }
    }
    // 2. Delete Firestore Documents
    const batch = admin.firestore().batch();
    if (userDoc.exists)
        batch.delete(userDoc.ref);
    if (adminDoc.exists)
        batch.delete(adminDoc.ref);
    if (lawyerDoc.exists)
        batch.delete(lawyerDoc.ref);
    batch.delete(admin.firestore().collection("passwordHistory").doc(uid));
    // Phone directory
    if (docData.phone) {
        const norm = normalizePhone(docData.phone);
        const digits = extractDigits(docData.phone);
        batch.delete(admin.firestore().collection("phone_directory").doc(norm));
        batch.delete(admin.firestore().collection("phone_directory").doc(digits));
    }
    await batch.commit();
    return { success: true, deletedUid: uid };
});
exports.adminCreateAdminAccount = functions.https.onCall(async (data, context) => {
    await verifyAdminCaller(context);
    const { phone, password, name, permissions } = data;
    if (!phone || !password || !name) {
        throw new functions.https.HttpsError("invalid-argument", "بيانات ناقصة");
    }
    const normPhone = normalizePhone(phone);
    const authEmail = toAuthEmail(normPhone);
    const digits = extractDigits(normPhone);
    const authKey = `MHMK-${digits}-SEC`;
    // Check if exists
    const existingDoc = await admin.firestore().collection("phone_directory").doc(normPhone).get();
    if (existingDoc.exists) {
        throw new functions.https.HttpsError("already-exists", "رقم الهاتف مسجل مسبقاً");
    }
    const hash = crypto.createHash('sha256').update(password.trim()).digest('hex');
    // Create in Auth
    let uid;
    try {
        const userRecord = await admin.auth().createUser({
            email: authEmail,
            password: authKey,
            displayName: name,
        });
        uid = userRecord.uid;
    }
    catch (err) {
        throw new functions.https.HttpsError("internal", `فشل إنشاء حساب Auth: ${err.message}`);
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const adminData = {
        uid,
        name,
        phone: normPhone,
        role: "subadmin",
        status: "active",
        permissions: permissions || [],
        createdAt: now,
        passwordHash: hash,
        adminResetPassword: password.trim(),
        passwordChangedAt: now,
    };
    const batch = admin.firestore().batch();
    batch.set(admin.firestore().collection("users").doc(uid), adminData);
    batch.set(admin.firestore().collection("phone_directory").doc(normPhone), adminData);
    await batch.commit();
    return { success: true, uid };
});
// Rate limit map (in-memory for simple rate limiting)
const rateLimits = {};
exports.verifyLoginFailureReason = functions.https.onCall(async (data, context) => {
    var _a, _b;
    const ip = context.rawRequest.ip || "unknown";
    const now = Date.now();
    if (!rateLimits[ip] || rateLimits[ip].resetTime < now) {
        rateLimits[ip] = { count: 0, resetTime: now + 60000 };
    }
    rateLimits[ip].count++;
    if (rateLimits[ip].count > 10) {
        throw new functions.https.HttpsError("resource-exhausted", "Too many attempts");
    }
    const { phone, password } = data;
    if (!phone || !password)
        throw new functions.https.HttpsError("invalid-argument", "Missing params");
    const normPhone = normalizePhone(phone);
    const dirDoc = await admin.firestore().collection("phone_directory").doc(normPhone).get();
    if (!dirDoc.exists)
        return { reason: "not_found" };
    const uid = (_a = dirDoc.data()) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid)
        return { reason: "not_found" };
    const hash = crypto.createHash('sha256').update(password.trim()).digest('hex');
    const historyDoc = await admin.firestore().collection("passwordHistory").doc(uid).get();
    if (historyDoc.exists) {
        const entries = ((_b = historyDoc.data()) === null || _b === void 0 ? void 0 : _b.entries) || [];
        for (const entry of entries) {
            if (entry.hash === hash) {
                return { reason: "old_password", changedAt: entry.changedAt };
            }
        }
    }
    return { reason: "wrong_password" };
});
exports.checkAccountStatus = functions.https.onCall(async (data, context) => {
    const { phone } = data;
    if (!phone)
        throw new functions.https.HttpsError("invalid-argument", "Missing phone");
    const ip = context.rawRequest.ip || "unknown";
    const now = Date.now();
    if (!rateLimits[ip] || rateLimits[ip].resetTime < now) {
        rateLimits[ip] = { count: 0, resetTime: now + 60000 };
    }
    rateLimits[ip].count++;
    if (rateLimits[ip].count > 30) {
        throw new functions.https.HttpsError("resource-exhausted", "Too many attempts");
    }
    const normPhone = normalizePhone(phone);
    const dirDoc = await admin.firestore().collection("phone_directory").doc(normPhone).get();
    if (!dirDoc.exists)
        return { exists: false };
    const docData = dirDoc.data();
    return {
        exists: true,
        role: (docData === null || docData === void 0 ? void 0 : docData.role) || 'client',
        status: (docData === null || docData === void 0 ? void 0 : docData.status) || 'active'
    };
});
exports.migrateFixAuthFirestoreMismatch = functions.https.onCall(async (data, context) => {
    var _a;
    const callerUid = await verifyAdminCaller(context);
    // Verify super admin
    const userDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!isSuperAdminPhone(((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.phone) || "")) {
        throw new functions.https.HttpsError("permission-denied", "هذه العملية متاحة للمشرف الأساسي فقط");
    }
    let fixedCount = 0;
    const errors = [];
    const usersSnap = await admin.firestore().collection("users").get();
    for (const doc of usersSnap.docs) {
        const uid = doc.id;
        const docData = doc.data();
        const phone = docData.phone;
        if (!phone)
            continue;
        const normPhone = normalizePhone(phone);
        const email = toAuthEmail(normPhone);
        const digits = extractDigits(normPhone);
        const authKey = `MHMK-${digits}-SEC`;
        try {
            const authUser = await admin.auth().getUser(uid);
            if (authUser.email !== email) {
                await admin.auth().updateUser(uid, { email, password: authKey });
                fixedCount++;
            }
        }
        catch (err) {
            if (err.code === "auth/user-not-found") {
                await admin.auth().createUser({ uid, email, password: authKey });
                fixedCount++;
            }
            else {
                errors.push(`Error for uid ${uid}: ${err.message}`);
            }
        }
    }
    return { success: true, fixedCount, errors };
});
// ============================================================================
// OLD FCM TRIGGERS (Preserved)
// ============================================================================
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
    }
    catch (error) {
        console.error("Error sending push notification for password reset:", error);
        return null;
    }
});
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
    }
    catch (error) {
        console.error("Error sending push notification for support message:", error);
        return null;
    }
});
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
    }
    catch (error) {
        console.error("Error sending push notification for new lawyer:", error);
        return null;
    }
});
//# sourceMappingURL=index.js.map