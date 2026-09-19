// ==============================================================================
// 🏛️ SUDAN CITY LANDMARK & MEDALLION WIDGET
// ==============================================================================
// Renders luxury 3D embossed medallions or custom vector painters
// dedicated exclusively to Sudanese cities and states.
// ==============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

class CityLandmarkWidget extends StatelessWidget {
  final String cityName;
  final double width;
  final double height;

  const CityLandmarkWidget({
    super.key,
    required this.cityName,
    this.width = 66,
    this.height = 66,
  });

  /// Resolves the dedicated photorealistic 3D embossed medallion asset path for Sudanese cities
  static String? getAssetPath(String cityName) {
    switch (cityName.trim()) {
      case 'الخرطوم':
        return 'assets/images/cities/khartoum.png';
      case 'أم درمان':
        return 'assets/images/cities/omdurman.png';
      case 'بحري':
        return 'assets/images/cities/bahri.png';
      case 'بورتسودان':
        return 'assets/images/cities/port_sudan.png';
      case 'كسلا':
        return 'assets/images/cities/kassala.png';
      case 'عطبرة':
        return 'assets/images/cities/atbara.png';
      case 'ود مدني':
        return 'assets/images/cities/wad_madani.png';
      case 'الأبيض':
        return 'assets/images/cities/el_obeid.png';
      case 'الفاشر':
        return 'assets/images/cities/el_fasher.png';
      case 'نيالا':
        return 'assets/images/cities/nyala.png';
      case 'دنقلا':
        return 'assets/images/cities/dongola.png';
      case 'كوستي':
        return 'assets/images/cities/kosti.png';
      case 'جميع المدن':
      case 'كافة المدن':
        return 'assets/images/cities/default_seal.png';

      // Regional Sudanese city affinities
      case 'مروي':
      case 'وادي حلفا':
        return 'assets/images/cities/dongola.png';
      case 'شندي':
      case 'بربر':
      case 'أبو حمد':
        return 'assets/images/cities/atbara.png';
      case 'سواكن':
      case 'طوكر':
        return 'assets/images/cities/port_sudan.png';
      case 'حلفا الجديدة':
      case 'القضارف':
        return 'assets/images/cities/kassala.png';
      case 'المناقل':
      case 'رفاعة':
      case 'الحصاحيصا':
        return 'assets/images/cities/wad_madani.png';
      case 'سنار':
      case 'سنجة':
      case 'الدمازين':
      case 'الدويم':
      case 'تندلتي':
        return 'assets/images/cities/kosti.png';
      case 'الجنينة':
      case 'زالنجي':
      case 'الضعين':
        return 'assets/images/cities/el_fasher.png';
      case 'النهود':
      case 'الفولة':
      case 'كادقلي':
      case 'الدلنج':
        return 'assets/images/cities/el_obeid.png';

      default:
        return 'assets/images/cities/default_seal.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double dimension = math.min(width, height);
    final String? assetPath = getAssetPath(cityName);

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Subtle warm gold rim glow
          BoxShadow(
            color: const Color(0xFFD49B1A).withValues(alpha: 0.16),
            blurRadius: 6,
            spreadRadius: 0,
          ),
          // Soft realistic drop shadow
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.10),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: assetPath != null
          ? ClipOval(
              child: Image.asset(
                assetPath,
                width: dimension,
                height: dimension,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    _buildProceduralFallback(dimension),
              ),
            )
          : _buildProceduralFallback(dimension),
    );
  }

  Widget _buildProceduralFallback(double dimension) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFFE57F),
            Color(0xFFD49B1A),
            Color(0xFFB45309),
            Color(0xFFD97706),
            Color(0xFFFFE57F),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2.2),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 0.85,
            colors: [
              Color(0xFF1E2F5E),
              Color(0xFF0B2A5B),
              Color(0xFF080F24),
            ],
          ),
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _LuxuryEmbossedMedallionPainter(cityName),
            size: Size(dimension - 4.4, dimension - 4.4),
          ),
        ),
      ),
    );
  }
}

class _LuxuryEmbossedMedallionPainter extends CustomPainter {
  final String cityName;
  _LuxuryEmbossedMedallionPainter(this.cityName);

  // Metallic gold paint palettes for 3D embossed bas-relief effect
  static const Color goldLight = Color(0xFFFFECB3); // Specular highlight
  static const Color goldBody = Color(0xFFFBBF24); // Warm polished gold
  static const Color goldDark = Color(0xFFB45309); // Shadow / Depth bronze
  static const Color goldDeep = Color(0xFF78350F); // Under-bevel shadow

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // 1. Concentric engraved legal seal rings inside the navy disc
    final ringPaint = Paint()
      ..color = const Color(0xFFD49B1A).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius * 0.90, ringPaint);
    canvas.drawCircle(center, radius * 0.84, ringPaint..strokeWidth = 0.4);

    // Subtle specular glass crescent highlight along the top rim
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.35))
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.90),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      highlightPaint,
    );

    // 2. Prepare Paints for 3D embossed architectural landmark
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [goldLight, goldBody, goldDark],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = goldDeep.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final name = cityName.trim();

    // 3. Render Sudanese city landmark matching the architectural heraldic style
    switch (name) {
      case 'الخرطوم':
        _drawKhartoumSail(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'أم درمان':
        _drawOmdurmanDome(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'بحري':
        _drawBahriBridge(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'بورتسودان':
        _drawPortSudanRedSea(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'كسلا':
        _drawKassalaTaka(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'عطبرة':
        _drawAtbaraRailway(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'ود مدني':
        _drawWadMadaniDome(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'الأبيض':
        _drawElObeidCathedral(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'الفاشر':
        _drawElFasherPalace(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'نيالا':
        _drawNyalaMountain(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'دنقلا':
        _drawDongolaNubian(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'كوستي':
        _drawKostiNile(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'مروي':
        _drawMerowePyramids(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'شندي':
        _drawShendiPylons(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'سواكن':
        _drawSuakinPort(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'القضارف':
        _drawGedarifSilos(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'سنار':
        _drawSennarDam(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
      case 'جميع المدن':
      case 'كافة المدن':
      default:
        _drawLegalJusticeSeal(canvas, size, bodyPaint, strokePaint, shadowPaint);
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. الخرطوم: برج الفاتح الشراعي الأيقوني وملتقى النيلين
  // ─────────────────────────────────────────────────────────────
  void _drawKhartoumSail(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    _drawWaterWaves(c, s, stroke, count: 3, yStart: h * 0.74);

    // Stepped Podium
    c.drawRect(Rect.fromLTWH(cx - w * 0.28, h * 0.65, w * 0.56, h * 0.08), body);

    // Iconic Sail-shaped Tower
    final sail = Path()
      ..moveTo(cx - w * 0.18, h * 0.65)
      ..cubicTo(cx - w * 0.25, h * 0.42, cx - w * 0.12, h * 0.20, cx, h * 0.18)
      ..cubicTo(cx + w * 0.18, h * 0.20, cx + w * 0.20, h * 0.48, cx + w * 0.12, h * 0.65)
      ..close();
    c.drawPath(sail, body);
    c.drawPath(sail, stroke);

    // Architectural floor rings
    for (double y = h * 0.26; y < h * 0.62; y += h * 0.06) {
      c.drawLine(Offset(cx - w * 0.12, y), Offset(cx + w * 0.12, y), stroke..strokeWidth = 0.7);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. أم درمان: قبة الإمام المهدي التاريخية والمئذنة الشامخة
  // ─────────────────────────────────────────────────────────────
  void _drawOmdurmanDome(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    // Dome base
    c.drawRect(Rect.fromLTWH(cx - w * 0.28, h * 0.62, w * 0.56, h * 0.16), body);
    c.drawRect(Rect.fromLTWH(cx - w * 0.28, h * 0.62, w * 0.56, h * 0.16), stroke);

    // Iconic Ribbed Dome
    final dome = Path()
      ..moveTo(cx - w * 0.20, h * 0.62)
      ..cubicTo(cx - w * 0.24, h * 0.38, cx + w * 0.24, h * 0.38, cx + w * 0.20, h * 0.62)
      ..close();
    c.drawPath(dome, body);
    c.drawPath(dome, stroke);

    // Crescent spire on dome
    c.drawLine(Offset(cx, h * 0.38), Offset(cx, h * 0.26), stroke..strokeWidth = 1.3);
    c.drawCircle(Offset(cx, h * 0.26), 2, body);

    // Minaret on side
    _drawSlenderMinaret(c, cx - w * 0.30, h * 0.24, w * 0.06, h * 0.44, body, stroke);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. بحري: جسر النيل المعلق
  // ─────────────────────────────────────────────────────────────
  void _drawBahriBridge(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    _drawWaterWaves(c, s, stroke, count: 3, yStart: h * 0.74);

    // Bridge Arch Truss
    final arch = Path()
      ..moveTo(w * 0.12, h * 0.62)
      ..quadraticBezierTo(cx, h * 0.25, w * 0.88, h * 0.62);
    c.drawPath(arch, stroke..strokeWidth = 2.0);

    // Deck
    c.drawLine(Offset(w * 0.10, h * 0.62), Offset(w * 0.90, h * 0.62), stroke..strokeWidth = 2.0);

    // Vertical stay cables
    for (double x = w * 0.20; x <= w * 0.80; x += w * 0.08) {
      c.drawLine(Offset(x, h * 0.62), Offset(x, h * 0.45), stroke..strokeWidth = 0.8);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. بورتسودان: منارة سنقنيب والبحر الأحمر
  // ─────────────────────────────────────────────────────────────
  void _drawPortSudanRedSea(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    _drawWaterWaves(c, s, stroke, count: 3, yStart: h * 0.72);

    // Sanganeb Coral Lighthouse Tower
    final lh = Path()
      ..moveTo(cx - w * 0.10, h * 0.72)
      ..lineTo(cx - w * 0.06, h * 0.28)
      ..lineTo(cx + w * 0.06, h * 0.28)
      ..lineTo(cx + w * 0.10, h * 0.72)
      ..close();
    c.drawPath(lh, body);
    c.drawPath(lh, stroke);

    // Beacon lantern gallery
    c.drawRect(Rect.fromLTWH(cx - w * 0.08, h * 0.24, w * 0.16, h * 0.04), body);
    c.drawCircle(Offset(cx, h * 0.20), 4, body);
    c.drawLine(Offset(cx, h * 0.20), Offset(cx, h * 0.14), stroke);

    // Flanking Ship on Right
    final ship = Path()
      ..moveTo(cx + w * 0.16, h * 0.68)
      ..lineTo(cx + w * 0.36, h * 0.68)
      ..lineTo(cx + w * 0.30, h * 0.76)
      ..lineTo(cx + w * 0.18, h * 0.76)
      ..close();
    c.drawPath(ship, body);
  }

  // ─────────────────────────────────────────────────────────────
  // 5. كسلا: جبال التوتيل والتاكا ونخيل القاش
  // ─────────────────────────────────────────────────────────────
  void _drawKassalaTaka(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    // Mount Taka Unique Smooth Granite Peaks
    final peakL = Path()
      ..moveTo(cx - w * 0.36, h * 0.72)
      ..cubicTo(cx - w * 0.28, h * 0.30, cx - w * 0.05, h * 0.22, cx - w * 0.04, h * 0.72)
      ..close();
    c.drawPath(peakL, body);
    c.drawPath(peakL, stroke);

    final peakR = Path()
      ..moveTo(cx - w * 0.08, h * 0.72)
      ..cubicTo(cx, h * 0.24, cx + w * 0.26, h * 0.32, cx + w * 0.36, h * 0.72)
      ..close();
    c.drawPath(peakR, body);
    c.drawPath(peakR, stroke);

    // Palm Tree in valley center
    _drawPalmTree(c, cx, h * 0.52, w * 0.18, h * 0.20, body, stroke);
  }

  // ─────────────────────────────────────────────────────────────
  // 6. عطبرة: عاصمة السكة حديد وقاطرة البخار
  // ─────────────────────────────────────────────────────────────
  void _drawAtbaraRailway(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    // Railway tracks
    c.drawLine(Offset(w * 0.12, h * 0.76), Offset(w * 0.88, h * 0.76), stroke..strokeWidth = 1.6);
    c.drawLine(Offset(w * 0.12, h * 0.81), Offset(w * 0.88, h * 0.81), stroke..strokeWidth = 1.6);
    for (double x = w * 0.16; x <= w * 0.84; x += w * 0.08) {
      c.drawLine(Offset(x, h * 0.74), Offset(x, h * 0.83), stroke..strokeWidth = 0.9);
    }

    // Classic Steam Locomotive Silhouette
    final loco = Path()
      ..moveTo(cx - w * 0.26, h * 0.76)
      ..lineTo(cx + w * 0.16, h * 0.76)
      ..lineTo(cx + w * 0.16, h * 0.56)
      ..lineTo(cx - w * 0.06, h * 0.56)
      ..lineTo(cx - w * 0.06, h * 0.44)
      ..lineTo(cx - w * 0.26, h * 0.44)
      ..close();
    c.drawPath(loco, body);
    c.drawPath(loco, stroke);

    // Smokestack & Wheels
    c.drawRect(Rect.fromLTWH(cx + w * 0.06, h * 0.44, w * 0.06, h * 0.12), body);
    c.drawCircle(Offset(cx - w * 0.16, h * 0.76), 4.5, body);
    c.drawCircle(Offset(cx + w * 0.06, h * 0.76), 4.5, body);
  }

  // ─────────────────────────────────────────────────────────────
  // 7. ود مدني: قبة وبوابة مشروع الجزيرة الخضراء
  // ─────────────────────────────────────────────────────────────
  void _drawWadMadaniDome(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    c.drawLine(Offset(w * 0.14, h * 0.76), Offset(w * 0.86, h * 0.76), stroke..strokeWidth = 1.5);

    // Gezira Monument Arch & Dome
    final arch = Path()
      ..moveTo(cx - w * 0.25, h * 0.76)
      ..lineTo(cx - w * 0.25, h * 0.50)
      ..quadraticBezierTo(cx, h * 0.26, cx + w * 0.25, h * 0.50)
      ..lineTo(cx + w * 0.25, h * 0.76)
      ..close();
    c.drawPath(arch, body);
    c.drawPath(arch, stroke);

    final inner = Path()
      ..moveTo(cx - w * 0.14, h * 0.76)
      ..lineTo(cx - w * 0.14, h * 0.56)
      ..quadraticBezierTo(cx, h * 0.42, cx + w * 0.14, h * 0.56)
      ..lineTo(cx + w * 0.14, h * 0.76)
      ..close();
    c.drawPath(inner, stroke..color = goldDark);
  }

  // ─────────────────────────────────────────────────────────────
  // 8. الأبيض: كاتدرائية الأبيض التراثية وقبة عروس الرمال
  // ─────────────────────────────────────────────────────────────
  void _drawElObeidCathedral(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    c.drawRect(Rect.fromLTWH(cx - w * 0.28, h * 0.58, w * 0.56, h * 0.18), body);
    c.drawRect(Rect.fromLTWH(cx - w * 0.28, h * 0.58, w * 0.56, h * 0.18), stroke);

    c.drawArc(Rect.fromCircle(center: Offset(cx, h * 0.58), radius: w * 0.18), math.pi, math.pi, true, body);
    c.drawArc(Rect.fromCircle(center: Offset(cx, h * 0.58), radius: w * 0.18), math.pi, math.pi, false, stroke);
    c.drawCircle(Offset(cx, h * 0.38), 2.5, body);

    c.drawRect(Rect.fromLTWH(cx - w * 0.30, h * 0.40, w * 0.08, h * 0.24), body);
    c.drawRect(Rect.fromLTWH(cx + w * 0.22, h * 0.40, w * 0.08, h * 0.24), body);
  }

  // ─────────────────────────────────────────────────────────────
  // 9. الفاشر: قصر السلطان علي دينار التاريخي
  // ─────────────────────────────────────────────────────────────
  void _drawElFasherPalace(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    c.drawRect(Rect.fromLTWH(cx - w * 0.32, h * 0.50, w * 0.64, h * 0.26), body);
    c.drawRect(Rect.fromLTWH(cx - w * 0.32, h * 0.50, w * 0.64, h * 0.26), stroke);

    for (double x = cx - w * 0.30; x <= cx + w * 0.30; x += w * 0.08) {
      c.drawRect(Rect.fromLTWH(x - w * 0.02, h * 0.44, w * 0.04, h * 0.06), body);
    }

    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.06, h * 0.60, w * 0.12, h * 0.16), const Radius.circular(3)), stroke..color = goldDark);
  }

  // ─────────────────────────────────────────────────────────────
  // 10. مروي ودنقلا: أهرامات كوش ومملكة نبتة ومروي النوبية
  // ─────────────────────────────────────────────────────────────
  void _drawMerowePyramids(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    final p1 = Path()
      ..moveTo(cx - w * 0.05, h * 0.24)
      ..lineTo(cx + w * 0.20, h * 0.74)
      ..lineTo(cx - w * 0.26, h * 0.74)
      ..close();
    c.drawPath(p1, body);
    c.drawPath(p1, stroke);

    final p2 = Path()
      ..moveTo(cx + w * 0.18, h * 0.34)
      ..lineTo(cx + w * 0.36, h * 0.74)
      ..lineTo(cx, h * 0.74)
      ..close();
    c.drawPath(p2, body);
    c.drawPath(p2, stroke);
  }

  void _drawDongolaNubian(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    _drawMerowePyramids(c, s, body, stroke, shadow);
  }

  // ─────────────────────────────────────────────────────────────
  // 11. نيالا: جبل نيالا ولؤلؤة دارفور
  // ─────────────────────────────────────────────────────────────
  void _drawNyalaMountain(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    final mtn = Path()
      ..moveTo(w * 0.10, h * 0.74)
      ..lineTo(cx, h * 0.32)
      ..lineTo(w * 0.90, h * 0.74)
      ..close();
    c.drawPath(mtn, body);
    c.drawPath(mtn, stroke);
    c.drawCircle(Offset(cx, h * 0.24), 3.5, body);
  }

  // ─────────────────────────────────────────────────────────────
  // 12. كوستي: جسر كوستي النيلي
  // ─────────────────────────────────────────────────────────────
  void _drawKostiNile(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    _drawBahriBridge(c, s, body, stroke, shadow);
  }

  void _drawShendiPylons(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    _drawMerowePyramids(c, s, body, stroke, shadow);
  }

  void _drawSuakinPort(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    _drawPortSudanRedSea(c, s, body, stroke, shadow);
  }

  void _drawGedarifSilos(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    c.drawLine(Offset(w * 0.12, h * 0.75), Offset(w * 0.88, h * 0.75), stroke);
    for (int i = -1; i <= 1; i++) {
      final x = cx + i * (w * 0.18);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - w * 0.08, h * 0.35, w * 0.16, h * 0.40), const Radius.circular(4)), body);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - w * 0.08, h * 0.35, w * 0.16, h * 0.40), const Radius.circular(4)), stroke);
    }
  }

  void _drawSennarDam(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final h = s.height;
    final w = s.width;

    _drawWaterWaves(c, s, stroke, count: 2, yStart: h * 0.76);
    c.drawRect(Rect.fromLTWH(cx - w * 0.36, h * 0.50, w * 0.72, h * 0.22), body);
    c.drawRect(Rect.fromLTWH(cx - w * 0.36, h * 0.50, w * 0.72, h * 0.22), stroke);
    for (double x = cx - w * 0.28; x <= cx + w * 0.28; x += w * 0.09) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - w * 0.03, h * 0.58, w * 0.06, h * 0.14), const Radius.circular(3)), stroke..color = goldDark);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // الختم القانوني العام: ميزان العدالة والأعمدة الكلاسيكية
  // ─────────────────────────────────────────────────────────────
  void _drawLegalJusticeSeal(Canvas c, Size s, Paint body, Paint stroke, Paint shadow) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final h = s.height;
    final w = s.width;

    // Central Pillar
    c.drawRect(Rect.fromLTWH(cx - 1.5, cy - h * 0.20, 3, h * 0.42), body);
    c.drawRect(Rect.fromLTWH(cx - 1.5, cy - h * 0.20, 3, h * 0.42), stroke);

    // Stepped Base
    c.drawRect(Rect.fromLTWH(cx - w * 0.14, cy + h * 0.22, w * 0.28, 4), body);
    c.drawRect(Rect.fromLTWH(cx - w * 0.18, cy + h * 0.25, w * 0.36, 4), body);

    // Balance Beam
    c.drawLine(Offset(cx - w * 0.24, cy - h * 0.16), Offset(cx + w * 0.24, cy - h * 0.16), stroke..strokeWidth = 2.0);

    // Left Scale Pan
    c.drawLine(Offset(cx - w * 0.24, cy - h * 0.16), Offset(cx - w * 0.28, cy - h * 0.04), stroke..strokeWidth = 0.8);
    c.drawLine(Offset(cx - w * 0.24, cy - h * 0.16), Offset(cx - w * 0.20, cy - h * 0.04), stroke..strokeWidth = 0.8);
    final panL = Path()
      ..moveTo(cx - w * 0.30, cy - h * 0.04)
      ..quadraticBezierTo(cx - w * 0.24, cy + h * 0.02, cx - w * 0.18, cy - h * 0.04)
      ..close();
    c.drawPath(panL, body);

    // Right Scale Pan
    c.drawLine(Offset(cx + w * 0.24, cy - h * 0.16), Offset(cx + w * 0.20, cy - h * 0.04), stroke..strokeWidth = 0.8);
    c.drawLine(Offset(cx + w * 0.24, cy - h * 0.16), Offset(cx + w * 0.28, cy - h * 0.04), stroke..strokeWidth = 0.8);
    final panR = Path()
      ..moveTo(cx + w * 0.18, cy - h * 0.04)
      ..quadraticBezierTo(cx + w * 0.24, cy + h * 0.02, cx + w * 0.30, cy - h * 0.04)
      ..close();
    c.drawPath(panR, body);
  }

  // ─────────────────────────────────────────────────────────────
  // HELPER DRAWING METHODS
  // ─────────────────────────────────────────────────────────────
  void _drawWaterWaves(Canvas c, Size s, Paint stroke, {required int count, required double yStart}) {
    final w = s.width;
    final wavePaint = Paint()
      ..color = const Color(0xFFD49B1A).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    for (int i = 0; i < count; i++) {
      final y = yStart + (i * s.height * 0.05);
      final p = Path()..moveTo(w * 0.16, y);
      for (double x = w * 0.16; x <= w * 0.84; x += w * 0.16) {
        p.quadraticBezierTo(x + w * 0.08, y - 2.5, x + w * 0.16, y);
      }
      c.drawPath(p, wavePaint);
    }
  }

  void _drawPalmTree(Canvas c, double x, double y, double w, double h, Paint body, Paint stroke) {
    final trunk = Path()
      ..moveTo(x, y + h)
      ..quadraticBezierTo(x + 3, y + h * 0.5, x, y);
    c.drawPath(trunk, stroke..strokeWidth = 1.3);

    c.drawLine(Offset(x, y), Offset(x - w * 0.45, y - h * 0.25), stroke..strokeWidth = 0.9);
    c.drawLine(Offset(x, y), Offset(x + w * 0.45, y - h * 0.25), stroke..strokeWidth = 0.9);
    c.drawLine(Offset(x, y), Offset(x - w * 0.35, y - h * 0.45), stroke..strokeWidth = 0.9);
    c.drawLine(Offset(x, y), Offset(x + w * 0.35, y - h * 0.45), stroke..strokeWidth = 0.9);
  }

  void _drawSlenderMinaret(Canvas c, double x, double y, double w, double h, Paint body, Paint stroke) {
    c.drawRect(Rect.fromLTWH(x - w / 2, y, w, h), body);
    c.drawRect(Rect.fromLTWH(x - w / 2, y, w, h), stroke..strokeWidth = 0.7);
    c.drawRect(Rect.fromLTWH(x - w * 0.75, y - 4, w * 1.5, 4), body);
    c.drawCircle(Offset(x, y - 8), w * 0.6, body);
    c.drawLine(Offset(x, y - 8), Offset(x, y - 14), stroke..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant _LuxuryEmbossedMedallionPainter oldDelegate) {
    return oldDelegate.cityName != cityName;
  }
}
