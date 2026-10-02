# منصة محاميك (Mahameek Platform) - دليل المهندس والتشغيل للإنتاج

منصة قانونية رقمية متطورة مصممة لمساعدة المواطنين والشركات في كافة ولايات ومدن السودان للوصول إلى نخبة من المحامين وموثقي العقود المعتمدين، والتواصل المباشر معهم عبر الهاتف والواتساب، مع نظام متكامل لإدارة المحامين وطلبات الانضمام.

---

## 🏛️ الهوية والتصميم (Identity & UI/UX)
- **الاتجاه واللغة**: اتجاه اليمين لليسار (RTL) بشكل أصيل وكامل، اللغة العربية السودانية الفصحى.
- **الخط**: خط **Cairo** من Google Fonts لكافة النصوص والأرقام.
- **الألوان**:
  - الكحلي الملكي العميق (Royal Navy): `#0F1B3E` / `#1B2B5E`
  - الذهبي الفاخر (Signature Gold / Amber): `#FFA000` / `#C9A84C` / `#F59E0B`
  - الرمادي الداكن والصفحات: `#FCFBF9` / `#F8FAFC`
- **إمكانية الوصول (Accessibility)**: احترام إعدادات تكبير الخط في النظام مع تأمين واجهات متجاوبة (Clamped Scaling: 0.85 - 1.35) تمنع أي Overflow.

---

## 🔒 بنية الأمان والتحكم بالوصول (Security Architecture)

### 1. إلغاء بيانات المشرف الثابتة (Hardcoded Credentials Removed)
- تم حذف أي كود كان يعتمد على `AdminCredentials` أو `Fake Admin Login`.
- المصدر الوحيد للمصادقة هو **Firebase Authentication**.
- لا يتم تخزين أي كلمة مرور أو هاش لكلمة مرور داخل **Cloud Firestore**.

### 2. الأدوار والصلاحيات (Role-Based Access Control)
- **العميل (Client)**: قراءة وتعديل حسابه الشخصي فقط؛ قراءة المحامين المعتمدين (`status == 'approved'`) فقط؛ مراسلة الإدارة.
- **المحامي (Lawyer)**:
  - عند التسجيل ينتقل تلقائياً إلى حالة **قيد المراجعة (`pending`)** ويوجه لشاشة الانتظار `LawyerPendingScreen`، ولا يمكنه الدخول كعميل أو الظهور في قوائم البحث حتى تتم الموافقة عليه.
  - المحامي المعتمد فقط هو من يملك صلاحية تعديل بياناته المهنية عبر حسابه الموثق.
- **المشرف (Admin)**:
  - التحقق المزدوج عبر Firebase Auth وسجل المشرفين في Firestore (`users/{uid}.role == 'admin'` أو وجوده في مجموعة `admins/{uid}`).
  - إضافة مشرفين جدد تتم عبر Firebase Authentication مع حفظ الدور في Firestore دون أي تخزين لكلمات المرور.
  - العمليات الحساسة (قبول/رفض المحامي، حذف المستخدمين) مقيدة تماماً عبر قواعد الأمان Firestore Rules.

### 3. قواعد أمان Firestore (`firestore.rules`)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() { return request.auth != null; }
    function isOwner(userId) { return isAuthenticated() && request.auth.uid == userId; }
    function isAdmin() {
      return isAuthenticated() && (
        request.auth.token.admin == true ||
        request.auth.token.role == 'admin' ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' ||
        exists(/databases/$(database)/documents/admins/$(request.auth.uid))
      );
    }
    // راجع ملف firestore.rules للتفاصيل الكاملة
  }
}
```

---

## 📸 تخزين الصور وFirebase Storage

- تم نقل تخزين الصور الشخصية من **Base64** داخل Firestore إلى **Firebase Storage** عبر الخدمة المخصصة `StorageService`.
- يتم تخزين رابط التحميل `photoUrl` الآمن فقط في Firestore.
- ضغط الصور تلقائياً والتحقق من الحجم (بحد أقصى 5 ميجابايت).
- حذف الصورة القديمة تلقائياً من Storage عند تحديث الصورة أو إزالتها لتفادي تراكم الملفات المهملة.
- التوافق العكسي (Backward Compatibility): استمرار دعم الحسابات السابقة التي تحتوي على صور Base64 بدون أي توقف أو أخطاء.

---

## ⚡ الأداء وتحسين استعلامات Firestore

1. **استعلامات مفهرسة ومحددة**:
   - قراءة المحامين المعتمدين فقط عبر:
     `.where('status', isEqualTo: 'approved').orderBy('createdAt', descending: true)`
2. **إحصائيات الخادم (Server-side Count Aggregations)**:
   - استخدام `aggregate(count())` لحساب عدد المحامين والعملاء دون تحميل جميع المستندات واستهلاك الحصة المجانية/المدفوعة.
3. **تحديث ذري (Atomic Transactions / WriteBatch)**:
   - تحديث مجموعتي `users` و `lawyers` في نفس العملية الذرية لضمان تطابق البيانات وعدم حدوث انقسام (Data Desync).
4. **تنظيف الكاش (Cache Invalidation)**:
   - عند حذف أو إلغاء اعتماد محامٍ وتفريغ القائمة، يتم تحديث وحذف بيانات الكاش المحلي فوراً لمنع ظهور محامين ملغيين للمستخدمين.

---

## 🛠️ أوامر التشغيل والاختبار (Commands & Testing)

### الفحص الثابت وتحليل الكود:
```bash
flutter analyze
```
*(النتيجة المتوقعة: `No issues found!` بدون أي أخطاء أو تحذيرات).*

### تشغيل حزمة الاختبارات الشاملة (Unit & Widget Tests):
```bash
flutter test
```
تشمل الحزمة:
- `test/models_test.dart`: اختبارات النماذج، الصلاحيات، وتحليل الحقول.
- `test/cache_and_state_test.dart`: اختبارات التخزين المؤقت وحذف الكاش عند البيانات الفارغة.
- `test/ui_rtl_test.dart`: اختبارات اتجاه RTL، خط Cairo، بطاقات المحامين وعدم حدوث Overflow.

---

## 🚀 نشر قواعد Firebase (Firebase Rules Deployment)

عند امتلاك صلاحيات الوصول لمشروع Firebase في بيئة العمل، نفذ الأمر التالي لنشر القواعد المحدثة:
```bash
firebase deploy --only firestore:rules,storage
```

---

## 📦 التوقيع والبناء للإنتاج (Android Release Signing & Build)

1. انسخ ملف الإعداد النموذجي:
   ```bash
   cp android/key.properties.example android/key.properties
   ```
2. ضع مسار ملف الـ Keystore الخاص بك وبيانات السرية داخل `android/key.properties`:
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=YOUR_KEY_ALIAS
   storeFile=../my-release-key.jks
   ```
3. بناء تطبيق أندرويد للإنتاج (App Bundle لمتجر Google Play):
   ```bash
   flutter build appbundle --release
   ```
   أو إنشاء APK للتثبيت المباشر:
   ```bash
   flutter build apk --release
   ```

---

## 📋 متطلبات النشر للإنتاج (Production Launch Checklist)

- [x] إزالة بيانات المشرف الثابتة (01146979833 / 123).
- [x] ربط تسجيل الدخول بـ Firebase Auth حصراً.
- [x] فصل صلاحيات المشرف والتحقق منها عبر Firestore Rules وRoute Guards.
- [x] توجيه المحامي قيد المراجعة (`pending`) إلى شاشة الانتظار.
- [x] استخدام Firebase Storage وحذف الصور القديمة.
- [x] تحسين استعلامات Firestore وإحصائيات Count Aggregations.
- [x] منع نجاح العمليات الكاذب ومعالجة انقطاع الاتصال.
- [x] تجهيز `key.properties` وحماية المفاتيح في `.gitignore`.
- [x] فحص وتحليل كامل بدون أخطاء (`flutter analyze` & `flutter test` passed).
- [x] استبدال معرّف الحزمة الافتراضي بمعرف الإنتاج المعتمد (`com.mahameek.app`) في Android و iOS.
- [x] إنشاء مفتاح التوقيع الرسمي `upload-keystore.jks` وربطه عبر `android/key.properties`.
- [x] إتاحة حذف الحساب والبيانات نهائياً للمحامين والعملاء تلبيةً لمعايير متجر آبل (Guideline 5.1.1(v)).
- [x] صياغة وثيقة سياسة الخصوصية الشاملة (`web/privacy_policy.html` و `PRIVACY_POLICY.md`).
- [ ] إنشاء أول حساب مشرف رسمي عبر Firebase Console (أو عبر شاشة تسجيل الدخول بعد إضافة دور `admin` في وثيقة المستخدم).
- [ ] نشر قواعد `firestore.rules` و `storage.rules` على خوادم Firebase الحية عبر Firebase CLI (`firebase deploy --only firestore:rules,storage`).
