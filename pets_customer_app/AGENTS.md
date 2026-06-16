# AGENTS.md — Pets Customer App (Flutter)

## 📌 نظرة عامة

هذا المشروع هو **تطبيق عميل Flutter** B2B لمنصة مُنتجات. يتكون من:
- **Frontend:** Flutter (Dart)
- **API:** يتصل بـ sapconnect REST API
- **Features:** Store, Cart, Orders, Invoices, Profile

## 🏗️ الهيكل المعماري

```
pets_customer_app/
├── lib/
│   ├── main.dart                        # Entry point + AppTheme
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart       # Base URL + Endpoints
│   │   ├── theme/
│   │   │   ├── app_theme.dart           # Material Theme
│   │   │   └── app_colors.dart          # Color Palette
│   │   ├── utils/                       # Helpers, Extensions
│   │   └── widgets/                     # Reusable Widgets
│   └── features/
│       ├── auth/
│       │   └── presentation/
│       │       └── pages/
│       │           ├── splash_screen.dart
│       │           ├── onboarding_screen.dart
│       │           ├── language_screen.dart
│       │           ├── login_screen.dart      # OTP Phone Login
│       │           ├── otp_screen.dart
│       │           └── register_company_screen.dart
│       ├── store/
│       │   ├── data/
│       │   │   ├── models/
│       │   │   │   ├── brand_model.dart
│       │   │   │   └── product_model.dart
│       │   │   └── repositories/
│       │   │       └── store_repository.dart
│       │   └── presentation/
│       │       └── pages/
│       │           ├── store_screen.dart         # Main Store
│       │           ├── categories_screen.dart
│       │           └── products_list_screen.dart
│       ├── product/
│       │   └── presentation/
│       │       ├── pages/
│       │       │   └── product_details_screen.dart
│       │       └── widgets/
│       │           ├── product_card.dart
│       │           └── product_horizontal_card.dart
│       ├── cart/
│       │   └── presentation/
│       │       └── pages/
│       │           ├── cart_screen.dart
│       │           └── order_confirmation_screen.dart
│       ├── home/
│       │   └── presentation/
│       │       └── pages/
│       │           ├── main_layout.dart     # Bottom Navigation
│       │           └── home_screen.dart
│       └── profile/
│           └── presentation/
│               └── pages/
│                   ├── profile_dashboard_screen.dart
│                   ├── orders_screen.dart
│                   ├── invoices_screen.dart
│                   ├── invoice_details_screen.dart
│                   └── returns_screen.dart
├── assets/
│   ├── images/
│   │   ├── logo_transparent.png
│   │   └── store/
│   │       ├── top_banner_1.png
│   │       ├── top_banner_2.png
│   │       └── top_banner_3.png
│   ├── images/onboarding/
│   └── svgs/
├── pubspec.yaml
└── analysis_options.yaml
```

## 🔧 التقنيات المستخدمة

| التقنية | الإصدار | الاستخدام |
|---------|---------|-----------|
| Flutter SDK | ^3.7.0 | Framework |
| Dart | ^3.7.0 | Language |
| http | ^1.6.0 | HTTP Client |
| iconsax | ^0.0.8 | Icons |
| carousel_slider | ^5.0.0 | Banners Carousel |
| smooth_page_indicator | ^1.2.0 | Page Indicators |
| flutter_svg | ^2.2.2 | SVG Support |
| device_preview | ^1.2.0 | Development Preview |

## 🧑‍💼 أنماط التطوير

### 1. Clean Architecture (Simplified)
```
features/
├── feature_name/
│   ├── data/
│   │   ├── models/         # Data Models (fromJson, toJson)
│   │   └── repositories/   # API Calls
│   └── presentation/
│       ├── pages/          # Screens (StatefulWidget)
│       └── widgets/        # Reusable Components
```

### 2. Model Pattern
```dart
class ProductModel {
  final String itemCode;
  final String itemName;
  // ...

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      itemCode: json['item_code'],
      itemName: json['item_name'],
      // ...
    );
  }
}
```

### 3. Repository Pattern
```dart
class StoreRepository {
  Future<List<BrandModel>> getBrands() async {
    final response = await http.get(Uri.parse(ApiConstants.brands));
    // Parse and return
  }

  Future<List<ProductModel>> getProducts({String? brandCode}) async {
    // Build URL with query params
    // Parse paginated response
  }
}
```

### 4. API Constants
```dart
// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://sapapi.muntajat.sa/api';
  static const String brands = '$baseUrl/store/brands';
  static const String products = '$baseUrl/store/products';
}
```

## 📱 الشاشات

| الشاشة | المسار | الوصف |
|--------|--------|-------|
| Splash | `splash_screen.dart` | شاشة البداية |
| Onboarding | `onboarding_screen.dart` | دليل الاستخدام |
| Language | `language_screen.dart` | اختيار اللغة |
| Login | `login_screen.dart` | تسجيل الدخول بالهاتف |
| OTP | `otp_screen.dart` | التحقق من الرمز |
| Register Company | `register_company_screen.dart` | تسجيل الشركة |
| Store | `store_screen.dart` | المتجر الرئيسي |
| Categories | `categories_screen.dart` | التصنيفات |
| Products List | `products_list_screen.dart` | قائمة المنتجات |
| Product Details | `product_details_screen.dart` | تفاصيل المنتج |
| Cart | `cart_screen.dart` | سلة التسوق |
| Order Confirmation | `order_confirmation_screen.dart` | تأكيد الطلب |
| Profile | `profile_dashboard_screen.dart` | الملف الشخصي |
| Orders | `orders_screen.dart` | طلباتي |
| Invoices | `invoices_screen.dart` | الفواتير |
| Invoice Details | `invoice_details_screen.dart` | تفاصيل الفاتورة |
| Returns | `returns_screen.dart` | المرتجعات |

## 🌐 API Integration

### Public Endpoints (No Auth):
```dart
GET /api/store/brands        → List<BrandModel>
GET /api/store/products      → Paginated<ProductModel>
GET /api/store/proxy-image   → Proxy for product images
```

### Auth Endpoints (Sanctum Token):
```dart
POST /api/login              → { token, user }
POST /api/verify-otp         → { token, user }
POST /api/logout             → 204
GET  /api/profile            → User
PUT  /api/profile            → Updated User
GET  /api/warehouses         → List<Warehouse>
GET  /api/stock-transfers    → List<StockTransfer>
```

## 📝 اصطلاحات الكود

### إضافة Screen جديد:
```dart
// في features/{feature}/presentation/pages/
class NewScreen extends StatefulWidget {
  const NewScreen({super.key});

  @override
  State<NewScreen> createState() => _NewScreenState();
}

class _NewScreenState extends State<NewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(...),
      body: ...,
    );
  }
}
```

### إضافة Widget Reusable:
```dart
// في core/widgets/ أو features/{feature}/presentation/widgets/
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(...);
  }
}
```

### إضافة Model:
```dart
// في features/{feature}/data/models/
class NewModel {
  final String id;
  final String name;

  NewModel({required this.id, required this.name});

  factory NewModel.fromJson(Map<String, dynamic> json) {
    return NewModel(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
```

## 🧪 الاختبارات

```bash
# تشغيل التطبيق
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

## 🚀 Deploy

### Android:
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS:
```bash
flutter build ios --release
```

## 🌐 اللغة

- التطبيق: عربي (افتراضي) + إنجليزي
- Text Direction: RTL
- Font: Expo Arabic (or system font fallback)

## ⚠️ ملاحظات مهمة

1. **Device Preview:** مفعل حالياً للتطوير — قم بإزالته قبل الإنتاج
2. **Image Assets:** كل الصور في `assets/images/` و `assets/svgs/`
3. **API Base URL:** يجب تحديثه حسب البيئة (dev/staging/prod)
4. **State Management:** حالياً StatefulWidget فقط — يمكن ترقيته لـ Riverpod/Bloc
5. **Auth Token:** يُخزن في SharedPreferences (غير مُطبق حالياً)

## 🔗 روابط مهمة

- **API Base:** `https://sapapi.muntajat.sa/api`
- **Product Images:** `https://ppte.sa/imghd/{item_code}.png`
- **Flutter Docs:** https://docs.flutter.dev
