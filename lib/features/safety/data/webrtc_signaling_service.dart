import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/providers/app_providers.dart';

enum CallStatus { idle, connecting, ringing, connected, ended }

class CallSession {
  const CallSession({
    required this.callId,
    required this.tripId,
    required this.callerId,
    required this.receiverId,
    required this.status,
    this.createdAt,
  });

  final String callId;
  final String tripId;
  final String callerId;
  final String receiverId;
  final CallStatus status;
  final DateTime? createdAt;

  factory CallSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final statusStr = data['status'] as String? ?? 'idle';
    final status = switch (statusStr) {
      'connecting' => CallStatus.connecting,
      'ringing' => CallStatus.ringing,
      'connected' => CallStatus.connected,
      'ended' => CallStatus.ended,
      _ => CallStatus.idle,
    };

    DateTime? created;
    final rawTime = data['createdAt'];
    if (rawTime is Timestamp) {
      created = rawTime.toDate();
    }

    return CallSession(
      callId: doc.id,
      tripId: data['tripId'] as String? ?? '',
      callerId: data['callerId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      status: status,
      createdAt: created,
    );
  }
}

class WebRtcSignalingService {
  WebRtcSignalingService(this._firestore);

  final FirebaseFirestore? _firestore;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  StreamSubscription? _callSubscription;
  StreamSubscription? _candidatesSubscription;

  bool _isInitialized = false;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> initializeRenderers() async {
    if (_isInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isInitialized = true;
  }

  Future<MediaStream> openUserMedia({bool video = true, bool audio = true}) async {
    final mediaConstraints = <String, dynamic>{
      'audio': audio,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };

    final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream = stream;
    localRenderer.srcObject = stream;
    return stream;
  }

  /// Start a 1-on-1 intro call for a trip
  Future<String> startCall({
    required String tripId,
    required String callerId,
    required String receiverId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase Firestore is not initialized.');
    }

    await initializeRenderers();
    await openUserMedia(video: true, audio: true);

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    final callDoc = firestore.collection('calls').doc();
    final callerCandidatesCollection = callDoc.collection('callerCandidates');

    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        callerCandidatesCollection.add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    // Create SDP Offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await callDoc.set({
      'tripId': tripId,
      'callerId': callerId,
      'receiverId': receiverId,
      'status': 'ringing',
      'offer': {'type': offer.type, 'sdp': offer.sdp},
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Listen for SDP Answer
    _callSubscription = callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      if (_peerConnection?.getRemoteDescription() == null &&
          data['answer'] != null) {
        final answerMap = data['answer'] as Map<String, dynamic>;
        final answer = RTCSessionDescription(
          answerMap['sdp'] as String?,
          answerMap['type'] as String?,
        );
        await _peerConnection?.setRemoteDescription(answer);
        await callDoc.update({'status': 'connected'});
      }
    });

    // Listen for remote ICE Candidates
    _candidatesSubscription = callDoc
        .collection('receiverCandidates')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final candidate = RTCIceCandidate(
              data['candidate'] as String?,
              data['sdpMid'] as String?,
              data['sdpMLineIndex'] as int?,
            );
            _peerConnection?.addCandidate(candidate);
          }
        }
      }
    });

    return callDoc.id;
  }

  /// Join an existing intro call
  Future<void> joinCall({
    required String callId,
    required String userId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebase Firestore is not initialized.');
    }

    await initializeRenderers();
    await openUserMedia(video: true, audio: true);

    final callDoc = firestore.collection('calls').doc(callId);
    final callSnapshot = await callDoc.get();

    if (!callSnapshot.exists) {
      throw StateError('Call does not exist.');
    }

    final data = callSnapshot.data()!;
    final offerMap = data['offer'] as Map<String, dynamic>;

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    final receiverCandidates = callDoc.collection('receiverCandidates');
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        receiverCandidates.add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    final offer = RTCSessionDescription(
      offerMap['sdp'] as String?,
      offerMap['type'] as String?,
    );
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await callDoc.update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': 'connected',
    });

    // Listen for remote ICE Candidates from caller
    _candidatesSubscription = callDoc
        .collection('callerCandidates')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final candidateData = change.doc.data();
          if (candidateData != null) {
            final candidate = RTCIceCandidate(
              candidateData['candidate'] as String?,
              candidateData['sdpMid'] as String?,
              candidateData['sdpMLineIndex'] as int?,
            );
            _peerConnection?.addCandidate(candidate);
          }
        }
      }
    });
  }

  /// End the call
  Future<void> endCall(String callId) async {
    try {
      if (_firestore != null && callId.isNotEmpty) {
        await _firestore.collection('calls').doc(callId).update({
          'status': 'ended',
        });
      }
    } catch (_) {}

    await _callSubscription?.cancel();
    await _candidatesSubscription?.cancel();

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((t) => t.stop());
    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  Stream<CallSession?> listenCallSession(String callId) {
    if (_firestore == null) return const Stream.empty();
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) => doc.exists ? CallSession.fromFirestore(doc) : null);
  }

  void dispose() {
    _callSubscription?.cancel();
    _candidatesSubscription?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
  }
}

final webrtcSignalingServiceProvider = Provider<WebRtcSignalingService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final service = WebRtcSignalingService(firestore);
  ref.onDispose(service.dispose);
  return service;
});
