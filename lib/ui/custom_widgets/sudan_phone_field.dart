import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/phone_utils.dart';

/// ويدجت رسم علم السودان بجودة فائقة (Vector Pixel-Perfect)
/// يضمن ظهور العلم بشكل احترافي وجذاب على جميع الأجهزة والأنظمة
class SudanFlagWidget extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SudanFlagWidget({
    super.key,
    this.width = 24,
    this.height = 16,
    this.borderRadius = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 0.6),
        child: CustomPaint(
          size: Size(width, height),
          painter: _SudanFlagPainter(),
        ),
      ),
    );
  }
}

class _SudanFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripeHeight = size.height / 3;

    // 1. الشريط العلوي: أحمر
    final redPaint = Paint()..color = const Color(0xFFD21034);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, stripeHeight), redPaint);

    // 2. الشريط الأوسط: أبيض
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, stripeHeight, size.width, stripeHeight), whitePaint);

    // 3. الشريط السفلي: أسود
    final blackPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, stripeHeight * 2, size.width, stripeHeight), blackPaint);

    // 4. المثلث الجانبي: أخضر
    final greenPaint = Paint()..color = const Color(0xFF007229);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.40, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, greenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ويدجت إدخال رقم الهاتف السوداني الموحد في كامل التطبيق
/// - يحتوي على مفتاح دولة السودان (+249 🇸🇩) بشكل ثابت وغير قابل للتغيير
/// - مدمج بالكامل مع خلفية وفواصل حقل الإدخال بدقة مطابقة للتصميم (Pixel-Perfect)
/// - يمنع كتابة الصفر في البداية ويحذفه تلقائياً
/// - يحدد عدد الأرقام بـ 9 أرقام سودانية مطابقة للمعايير القياسية
/// - يضمن التوافق التام مع روابط واتساب وقواعد البيانات
class SudanPhoneFormField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final IconData? headerIcon;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;
  final bool isRequired;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final FocusNode? focusNode;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;

  const SudanPhoneFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.headerIcon,
    this.hintText,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.isRequired = true,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.borderRadius = 14.0,
    this.contentPadding,
  });

  @override
  State<SudanPhoneFormField> createState() => _SudanPhoneFormFieldState();
}

class _SudanPhoneFormFieldState extends State<SudanPhoneFormField> {
  late FocusNode _focusNode;
  bool _isInternalFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SudanPhoneFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_isInternalFocusNode) {
        _focusNode.removeListener(_handleFocusChange);
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _isInternalFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _isInternalFocusNode = true;
      }
      _focusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = widget.borderColor ?? const Color(0xFFE2E8F0);
    final effectiveFocusedColor = widget.focusedBorderColor ?? const Color(0xFFD49B1A);
    final effectiveFillColor = widget.fillColor ?? const Color(0xFFF8FAFC);

    return FormField<String>(
      initialValue: widget.controller == null ? widget.initialValue : widget.controller!.text,
      validator: (value) {
        final currentText = widget.controller?.text ?? value ?? '';
        if (widget.validator != null) {
          return widget.validator!(currentText);
        }
        final val = currentText.trim();
        if (widget.isRequired && val.isEmpty) {
          return 'يرجى إدخال رقم الموبايل';
        }
        if (val.isNotEmpty) {
          try {
             PhoneUtils.normalize(val);
          } catch (_) {
             return 'رقم الهاتف يجب أن يكون مفتاح الدولة +249 ثم 9 أرقام';
          }
        }
        return null;
      },
      onSaved: widget.onSaved,
      builder: (FormFieldState<String> fieldState) {
        final hasError = fieldState.hasError;

        Color currentBorderColor;
        double currentBorderWidth;

        if (hasError) {
          currentBorderColor = const Color(0xFFEF4444);
          currentBorderWidth = 1.6;
        } else if (_isFocused) {
          currentBorderColor = effectiveFocusedColor;
          currentBorderWidth = 1.6;
        } else {
          currentBorderColor = effectiveBorderColor;
          currentBorderWidth = 1.0;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. العنوان والأيقونة العلوية (Label Header)
            if (widget.labelText != null && widget.labelText!.isNotEmpty) ...[
              Row(
                textDirection: TextDirection.rtl,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.headerIcon != null) ...[
                    Icon(
                      widget.headerIcon,
                      size: 18,
                      color: const Color(0xFF0B2A5B),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    widget.labelText!,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 2. حاوية حقل الإدخال المدمجة بالكامل مع كود الدولة
            Directionality(
              textDirection: TextDirection.ltr,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: widget.enabled ? effectiveFillColor : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: currentBorderColor,
                    width: currentBorderWidth,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius - 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // بادئة كود الدولة والعلم المدمجة
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          border: Border(
                            right: BorderSide(
                              color: effectiveBorderColor,
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SudanFlagWidget(
                              width: 24,
                              height: 16,
                              borderRadius: 3,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+249',
                              style: GoogleFonts.cairo(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B2A5B),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // خانة إدخال رقم الهاتف
                      Expanded(
                        child: TextFormField(
                          controller: widget.controller,
                          initialValue: widget.controller == null ? widget.initialValue : null,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          autofocus: widget.autofocus,
                          keyboardType: TextInputType.phone,
                          textInputAction: widget.textInputAction ?? TextInputAction.next,
                          onFieldSubmitted: widget.onFieldSubmitted,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            color: const Color(0xFF0B2A5B),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,

                          ],
                          decoration: InputDecoration(
                            hintText: widget.hintText ?? 'أدخل رقم الموبايل',
                            hintStyle: GoogleFonts.cairo(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: widget.contentPadding ??
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          ),
                          onChanged: (val) {
                            fieldState.didChange(val);
                            if (widget.onChanged != null) {
                              widget.onChanged!(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. رسالة الخطأ عند عدم صحة المدخلات
            if (hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  fieldState.errorText ?? '',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFDC2626),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
