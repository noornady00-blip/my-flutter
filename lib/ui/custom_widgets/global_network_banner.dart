// ==============================================================================
// 🌐 GLOBAL NETWORK BANNER WRAPPER
// ==============================================================================
// Overlays an intelligent, status-aware Arabic banner at the top of the screen
// indicating Wi-Fi without internet, cellular without internet, total disconnection,
// or internet restoration.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../network/network_service.dart';

/// Top-level network banner wrapper reacting to real connectivity and reachability changes.
class GlobalNetworkBannerWrapper extends StatefulWidget {
  final Widget child;
  const GlobalNetworkBannerWrapper({super.key, required this.child});

  @override
  State<GlobalNetworkBannerWrapper> createState() =>
      _GlobalNetworkBannerWrapperState();
}

class _GlobalNetworkBannerWrapperState
    extends State<GlobalNetworkBannerWrapper> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    HapticFeedback.lightImpact();
    await NetworkService().checkNow();
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkState>(
      valueListenable: NetworkService().stateNotifier,
      builder: (context, state, _) {
        final bool showBanner = state.status != NetworkStatus.online || state.isRestored;

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _NetworkPill(
                    state: state,
                    isRetrying: _isRetrying,
                    onRetry: _handleRetry,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NetworkPill extends StatefulWidget {
  final NetworkState state;
  final bool isRetrying;
  final VoidCallback onRetry;

  const _NetworkPill({
    required this.state,
    required this.isRetrying,
    required this.onRetry,
  });

  @override
  State<_NetworkPill> createState() => _NetworkPillState();
}

class _NetworkPillState extends State<_NetworkPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _resolveIcon(NetworkState state) {
    if (state.isRestored) {
      return Icons.wifi_rounded;
    }

    if (state.status == NetworkStatus.noConnection) {
      return Icons.wifi_off_rounded;
    }

    switch (state.transportType) {
      case NetworkTransportType.wifi:
        return Icons.signal_wifi_connected_no_internet_4_rounded;
      case NetworkTransportType.mobile:
        return Icons.signal_cellular_connected_no_internet_4_bar_rounded;
      case NetworkTransportType.multiple:
        return Icons.signal_wifi_connected_no_internet_4_rounded;
      case NetworkTransportType.none:
        return Icons.wifi_off_rounded;
      default:
        return Icons.signal_wifi_connected_no_internet_4_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bool isRestored = state.isRestored;
    final bool isFakeConn = state.status == NetworkStatus.connectedNoInternet;

    final Color accent = isRestored
        ? const Color(0xFF10B981) // Emerald Green
        : isFakeConn
            ? const Color(0xFFF59E0B) // Amber Gold
            : const Color(0xFFEF4444); // Red Alert

    final Color bgColor = isRestored
        ? const Color(0xFF022C22)
        : isFakeConn
            ? const Color(0xFF1C0F00)
            : const Color(0xFF1C0505);

    final IconData icon = _resolveIcon(state);
    final String label = state.message;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: [
                // Pulsing Status Dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.65),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Icon
                Icon(icon, color: accent, size: 16),
                const SizedBox(width: 6),

                // Status Message Text
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Retry Button (Hidden when restored)
                if (!isRestored) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.40),
                          width: 1,
                        ),
                      ),
                      child: widget.isRetrying
                          ? SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                color: accent,
                                strokeWidth: 1.8,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    color: accent, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  'فحص',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
