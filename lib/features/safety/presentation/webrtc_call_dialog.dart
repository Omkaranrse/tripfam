import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../data/webrtc_signaling_service.dart';

class WebRtcCallDialog extends ConsumerStatefulWidget {
  const WebRtcCallDialog({
    required this.tripId,
    required this.tripTitle,
    required this.callerId,
    required this.receiverId,
    this.existingCallId,
    super.key,
  });

  final String tripId;
  final String tripTitle;
  final String callerId;
  final String receiverId;
  final String? existingCallId;

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required String tripTitle,
    required String callerId,
    required String receiverId,
    String? existingCallId,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WebRtcCallDialog(
        tripId: tripId,
        tripTitle: tripTitle,
        callerId: callerId,
        receiverId: receiverId,
        existingCallId: existingCallId,
      ),
    );
  }

  @override
  ConsumerState<WebRtcCallDialog> createState() => _WebRtcCallDialogState();
}

class _WebRtcCallDialogState extends ConsumerState<WebRtcCallDialog> {
  String? _activeCallId;
  CallStatus _status = CallStatus.connecting;
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _startOrJoin();
  }

  Future<void> _startOrJoin() async {
    final signaling = ref.read(webrtcSignalingServiceProvider);
    try {
      if (widget.existingCallId != null && widget.existingCallId!.isNotEmpty) {
        _activeCallId = widget.existingCallId;
        setState(() => _status = CallStatus.connecting);
        await signaling.joinCall(
          callId: widget.existingCallId!,
          userId: widget.callerId,
        );
        setState(() => _status = CallStatus.connected);
      } else {
        setState(() => _status = CallStatus.ringing);
        final callId = await signaling.startCall(
          tripId: widget.tripId,
          callerId: widget.callerId,
          receiverId: widget.receiverId,
        );
        if (mounted) {
          setState(() {
            _activeCallId = callId;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = CallStatus.ended);
      }
    }
  }

  Future<void> _handleEndCall() async {
    if (_activeCallId != null) {
      await ref.read(webrtcSignalingServiceProvider).endCall(_activeCallId!);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signaling = ref.watch(webrtcSignalingServiceProvider);

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 500,
          height: 620,
          child: Stack(
            children: [
              // Remote Video / Placeholder
              Positioned.fill(
                child: _status == CallStatus.connected
                    ? RTCVideoView(
                        signaling.remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: const Color(0xFF15191E),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withAlpha(30),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.video_camera_front_rounded,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _status == CallStatus.ringing
                                    ? 'Calling companion...'
                                    : (_status == CallStatus.connecting
                                        ? 'Establishing WebRTC Connection...'
                                        : 'Call Ended'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.tripTitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // Local Camera Floating Preview
              Positioned(
                top: 20,
                right: 20,
                width: 120,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.5),
                    color: Colors.black87,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(120),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(
                    signaling.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

              // Top Header Bar
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _status == CallStatus.connected
                              ? Colors.green
                              : Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _status == CallStatus.connected
                            ? 'Encrypted P2P Call'
                            : 'Signaling via Firestore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Call Controls
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mute Button
                      FloatingActionButton.small(
                        heroTag: 'webrtc_mute',
                        backgroundColor: _isMuted ? Colors.red : Colors.white24,
                        onPressed: () {
                          setState(() => _isMuted = !_isMuted);
                          // Toggle audio track
                        },
                        child: Icon(
                          _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),

                      // End Call Button
                      FloatingActionButton(
                        heroTag: 'webrtc_end',
                        backgroundColor: Colors.redAccent,
                        onPressed: _handleEndCall,
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Camera Toggle
                      FloatingActionButton.small(
                        heroTag: 'webrtc_cam',
                        backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
                        onPressed: () {
                          setState(() => _isCameraOff = !_isCameraOff);
                          // Toggle video track
                        },
                        child: Icon(
                          _isCameraOff
                              ? Icons.videocam_off_rounded
                              : Icons.videocam_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
