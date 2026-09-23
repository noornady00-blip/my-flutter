# 📄 وثيقة تسليم المشروع للعميل (Client Project Handover)
## منصة وتطبيق محاميك (Mahameek Platform) — الإصدار الرسمي 1.0.0

مرحباً بك، هذه الوثيقة تمثل التوثيق الهندسي الشامل لتسليم مشروع **منصة محاميك** (Mahameek)، ومعدة وفق أفضل الممارسات المتبعة عالمياً لتسليم المشاريع البرمجية للعملاء، بحيث تضمن لك ملكية كاملة واحتفاظاً آمناً بكافة مصادر المشروع (Source Code)، وقواعد البيانات، ومفاتيح التوقيع، وحزم النشر للإنتاج.

---

### 1. 📌 بيانات المشروع والإصدار
* **اسم المشروع:** منصة محاميك (Mahameek)
* **رقم الإصدار المعتمد:** `1.0.0` (كود البناء `+1`)
* **معرّف التطبيق (Bundle ID / Application ID):** `com.mahameek.app`
* **بيئة التطوير:** Flutter 3.44.0 / Dart 3.12.0
* **الخوادم والبنية التحتية:** Google Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Functions, Cloud Messaging)
* **المستودع الرئيسي (GitHub):** [https://github.com/noornady00-blip/my-flutter](https://github.com/noornady00-blip/my-flutter)
* **الفرع الأساسي للإنتاج:** `main`

---

### 2. 📦 حزم التطبيق الجاهزة للإطلاق (Production Release Artifacts)
تم بناء وتجهيز 3 نسخ إنتاجية رئيسية جاهزة للتسليم:

| نوع الحزمة | اسم الملف | المنصة المستهدفة | الغرض والاستخدام |
| :--- | :--- | :--- | :--- |
| **Android App Bundle** | `app-release.aab` | Google Play Store | مخصصة للرفع المباشر على حساب المطور في **Google Play Console** |
| **Android APK** | `app-release.apk` | أجهزة Android | نسخة قابلة للتثبيت المباشر على الهواتف دون الحاجة للمتجر |
| **iOS IPA** | `Mahameek-unsigned.ipa` | هواتف iPhone / iPad | مخصصة لبيئة iOS (يتم بناؤها سحابياً عبر GitHub Actions على نظام macOS) |

* **مسار ملف الـ AAB محلياً:**
  `build/app/outputs/bundle/release/app-release.aab`
* **مسار ملف الـ APK محلياً:**
  `build/app/outputs/flutter-apk/app-release.apk`
* **رابط تحميل ملف الـ iOS IPA من GitHub Actions:**
  [https://github.com/noornady00-blip/my-flutter/actions](https://github.com/noornady00-blip/my-flutter/actions) (تحت اسم الأرتيفاكت: `Mahameek-iOS-IPA`)

---

### 3. 🔐 إرشادات حماية المفاتيح والأمان (Security & Keystores)
> [!IMPORTANT]
> **ملاحظة أمنية أساسية:**
> تم استثناء الملفات الحساسة تلقائياً من الرفع على GitHub عبر `.gitignore`، لحماية بياناتك وأمان تطبيقك من التسريب أو الاستغلال، وتشمل:
> 1. **مفتاح توقيع الأندرويد (`android/app/upload-keystore.jks`):** يجب الاحتفاظ بنسخة احتياطية منه على فلاشة أو قرص سحابي آمن خاص بك، حيث أنه المفتاح الوحيد الذي يسمح بتحديث التطبيق مستقبلاً على Google Play.
> 2. **بيانات كلمة مرور المفتاح (`android/key.properties`):** تحتوي على كلمات المرور واسم الـ Alias لمفتاح الـ Keystore.
> 3. **ملفات حسابات الخدمة (`functions/*service_account*.json`):** مفاتيح خاصة بصلاحيات الإدارة على Firebase.

---

### 4. 🗂️ هيكل مجلدات المشروع (Codebase Structure)
```text
mahameek/
├── lib/
│   ├── main.dart                          # نقطة الانطلاق الرئيسية وإعدادات البيئة
│   ├── firebase_options.dart              # ضبط الاتصال بمشروع Firebase
│   ├── data/
│   │   ├── models/                        # نماذج البيانات (المحامين، المستخدمين، الطلبات)
│   │   └── services/                      # خدمات Firebase (Auth, Firestore, Storage, Notifications)
│   └── ui/
│       ├── custom_widgets/                # المكونات المشتركة والـ Badges والأشرطة التفاعلية
│       ├── screens/
│       │   ├── auth/                      # بوابات تسجيل الدخول وإنشاء الحساب
│       │   ├── home/                      # الشاشة الرئيسية وعرض المحامين والخدمات
│       │   ├── cities/                    # دليل وتصفح ولايات ومدن السودان
│       │   ├── lawyers/                   # قائمة والبحث عن المحامين المعتمدين وتفاصيلهم
│       │   ├── lawyer/                    # لوحة تحكم وإعدادات المحامي
│       │   ├── admin/                     # لوحة تحكم المشرف (إدارة المحامين والمستخدمين)
│       │   └── profile/                   # الملف الشخصي وشروط الاستخدام وعن المنصة
├── android/                               # إعدادات تطبيق الأندرويد والتوقيع
├── ios/                                   # إعدادات تطبيق الآيفون والأيقونات
├── web/                                   # ملفات سياسة الخصوصية ونسخة الويب
├── functions/                             # دوال Firebase السحابية للإشعارات الفورية
├── firestore.rules                        # قواعد الحماية والأمان لقاعدة بيانات Firestore
├── storage.rules                          # قواعد الحماية لتخزين صور الملفات الشخصية
├── .github/workflows/                     # سير العمل السحابي لبناء iOS و Releases
├── pubspec.yaml                           # الحزم والمكتبات المعتمدة ورقم الإصدار (1.0.0)
└── README.md                              # الدليل الفني للمطور
```

---

### 5. ⚙️ أوامر التشغيل والبناء (Engineering Commands)

* **تثبيت الحزم والمكتبات:**
  ```bash
  flutter pub get
  ```

* **فحص الكود والتأكد من خلوه من الأخطاء:**
  ```bash
  flutter analyze
  ```

* **تشغيل حزمة الاختبارات الشاملة:**
  ```bash
  flutter test
  ```

* **بناء نسخة Android Bundle للإنتاج:**
  ```bash
  flutter build appbundle --release
  ```

* **بناء نسخة Android APK للإنتاج:**
  ```bash
  flutter build apk --release
  ```

* **نشر قواعد الأمان ودوال Firebase:**
  ```bash
  firebase deploy --only firestore:rules,storage,functions
  ```

---

### 6. 🛡️ سياسة الخصوصية ومتطلبات المتاجر
* تم تضمين صفحة سياسة الخصوصية الرسمية في ملف `PRIVACY_POLICY.md` وملف الويب `web/privacy_policy.html`.
* تم تطبيق متطلب متجر Apple Store لحذف الحساب نهائياً عبر زر حذف الحساب في إعدادات الملف الشخصي مع دالة Firebase السحابية `deleteMyAccount`.
* التطبيق يحترم حقوق الملكية الفكرية وعلامة **محاميك** التجارية بالكامل.

---
**تاريخ التسليم:** سبتمبر 2026  
**حالة المشروع:** جاهز للإطلاق بالكامل (Production Ready)  
