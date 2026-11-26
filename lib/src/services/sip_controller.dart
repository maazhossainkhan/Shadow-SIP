import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:medut/medut.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/call_log.dart';
import '../models/phone_contact.dart';
import 'local_data_store.dart';
import 'profile_store.dart';

class SipController extends ChangeNotifier {
  final ProfileStore _profileStore = ProfileStore();
  final LocalDataStore _dataStore = LocalDataStore();

  Medut? _sdk;
  Account? _account;
  Call? _call;
  StreamSubscription<MedutEvent>? _events;
  Timer? _durationTicker;

  SipProfile? savedProfile;
  List<CallLogItem> history = [];
  List<PhoneContact> contacts = [];
  MediaStats? latestStats;
  List<AudioDevice> inputDevices = [];
  List<AudioDevice> outputDevices = [];
  String? selectedInputDevice;
  String? selectedOutputDevice;

  RegState registrationState = RegState.unregistered;
  CallState? callState;
  String registrationMessage = 'No SIP account connected';
  String notice = '';
  String activePeer = '';
  bool isOutgoing = false;
  bool isMuted = false;
  bool isHeld = false;
  bool isSpeaker = false;
  bool isRecording = false;
  String recordingPath = '';
  DateTime? callStartedAt;
  Duration callDuration = Duration.zero;
  bool busy = false;

  Call? get activeCall => _call;
  Account? get activeAccount => _account;
  bool get isConnected => registrationState == RegState.registered;
  bool get hasCall => _call != null && callState != null && !callState!.isTerminal;

  // Quality-first defaults from the Medut-SDK API: Opus with FEC, adaptive
  // jitter buffering and bitrate, network recovery, and continuous metrics.
  // FEC is enabled dynamically by the SDK as RTCP loss reports arrive.
  static const _sdkConfig = MedutConfig(
    userAgent: 'Shadow-SIP/0.1.0',
    statsIntervalMs: 2000,
    mediaStallMs: 3000,
    mosAlertThreshold: 3.5,
    lossAlertThreshold: 5.0,
    jitterAlertThreshold: 40.0,
    jitterBufferType: JitterBufferType.adaptive,
    jitterBufferMinMs: 40,
    jitterBufferMaxMs: 400,
    adaptiveBitrate: true,
    opusExpectedLossPct: 0,
    opus: OpusConfig(bitrate: 32000, complexity: 9, fec: true, dtx: true),
    aecMode: AecMode.suppressor,
    noiseSuppression: true,
    autoGainControl: true,
    keepaliveIntervalMs: 30000,
    keepaliveReregister: true,
    regRetryInitialMs: 2000,
    regRetryMaxMs: 60000,
    regRetryBackoff: 2.0,
    regRetryJitter: 0.2,
    sipTimerBMs: 10000,
  );

  Future<void> initialize() async {
    savedProfile = await _profileStore.load();
    history = await _dataStore.loadHistory();
    contacts = await _dataStore.loadContacts();
    try {
      _sdk = await Medut.start(
        telecom: Platform.isAndroid,
        config: _sdkConfig,
      );
      _events ??= _sdk!.events.listen(_handleEvent);
      await refreshAudioDevices();

      // Native Android may already have restored an account before Flutter starts.
      if (_sdk!.accounts.isNotEmpty) {
        _account = _sdk!.accounts.first;
        registrationState = _account!.regState;
        registrationMessage = 'Restored ${_account!.aor}';
      }
      // Adopt a call that arrived through the native call framework before UI attached.
      final liveCalls = _sdk!.calls.where((c) => !c.state.isTerminal);
      if (liveCalls.isNotEmpty) {
        _call = liveCalls.first;
        callState = _call!.state;
        activePeer = _call!.remoteDisplayName ?? _call!.remoteUri;
        isOutgoing = _call!.isOutgoing;
        if (callState == CallState.established || callState == CallState.held) {
          _startDurationTimer();
        }
      }
    } on MedutException catch (e) {
      registrationMessage = 'SIP engine unavailable: ${e.message ?? e.code}';
      notice = registrationMessage;
    } catch (e) {
      registrationMessage = 'Could not start SIP engine: $e';
      notice = registrationMessage;
    }
    notifyListeners();
  }

  Future<void> connect(SipProfile profile) async {
    if (busy) return;
    busy = true;
    notice = '';
    notifyListeners();
    try {
      if (_sdk == null) {
        _sdk = await Medut.start(
          telecom: Platform.isAndroid,
          config: _sdkConfig,
        );
        _events ??= _sdk!.events.listen(_handleEvent);
        await refreshAudioDevices();
      }

      if (Platform.isAndroid) {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          throw Exception('Microphone permission is required for voice calls.');
        }
        await Permission.notification.request();
      }

      final isWebSocket = profile.transport == Transport.ws ||
          profile.transport == Transport.wss;
      if (isWebSocket && profile.serverUrl.trim().isEmpty) {
        throw Exception('WS/WSS requires a server URL, for example wss://pbx.example.com:8089/ws.');
      }
      if (profile.uri.trim().isEmpty || !profile.uri.contains('@')) {
        throw Exception('Enter a SIP address such as 201@pbx.example.com.');
      }

      await _account?.destroy(forget: true);
      _account = null;

      final config = AccountConfig(
        transport: profile.transport,
        serverUrl: isWebSocket && profile.serverUrl.trim().isNotEmpty ? profile.serverUrl.trim() : null,
        authUser: profile.authUser.trim().isEmpty ? null : profile.authUser.trim(),
        displayName: profile.displayName.trim().isEmpty ? null : profile.displayName.trim(),
        mediaEnc: isWebSocket ? MediaEncryption.dtlsSrtp : profile.mediaEncryption,
        iceEnabled: isWebSocket || profile.iceEnabled,
        stunServer: (isWebSocket || profile.iceEnabled) && profile.stunServer.trim().isNotEmpty ? profile.stunServer.trim() : null,
        turnServer: (isWebSocket || profile.iceEnabled) && profile.turnServer.trim().isNotEmpty ? profile.turnServer.trim() : null,
        turnUser: (isWebSocket || profile.iceEnabled) && profile.turnUser.trim().isNotEmpty ? profile.turnUser.trim() : null,
        turnPass: (isWebSocket || profile.iceEnabled) && profile.turnPassword.isNotEmpty ? profile.turnPassword : null,
        audioCodecs: const ['opus', 'ulaw', 'alaw'],
        verifyTls: true,
      );

      _account = await _sdk!.createAccount(
        profile.uri.trim(),
        profile.password,
        remember: Platform.isAndroid,
        config: config,
      );
      registrationState = RegState.registering;
      registrationMessage = 'Registering with SIP server…';
      notifyListeners();
      await _account!.register();
      await _profileStore.save(profile);
      savedProfile = profile;
    } on MedutException catch (e) {
      notice = 'SIP error: ${e.message ?? e.code}';
      registrationMessage = notice;
    } catch (e) {
      notice = e.toString().replaceFirst('Exception: ', '');
      registrationMessage = notice;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      if (isRecording) await stopRecording();
      await _call?.hangup();
      await _account?.destroy(forget: true);
    } catch (_) {}
    _account = null;
    _call = null;
    callState = null;
    registrationState = RegState.unregistered;
    registrationMessage = 'Disconnected';
    _stopDurationTimer();
    isMuted = false;
    isHeld = false;
    isSpeaker = false;
    isRecording = false;
    notifyListeners();
  }

  Future<void> forgetProfile() async {
    await disconnect();
    await _profileStore.clear();
    savedProfile = null;
    registrationMessage = 'Saved SIP account removed';
    notifyListeners();
  }

  Future<void> dialConference() async {
    final room = savedProfile?.conferenceUri.trim() ?? '';
    if (room.isEmpty) {
      notice = 'Add your PBX conference room extension in Settings first.';
      notifyListeners();
      return;
    }
    await dial(room);
  }

  Future<void> dial(String destination) async {
    final account = _account;
    if (account == null || !isConnected) {
      notice = 'Connect a registered SIP account first.';
      notifyListeners();
      return;
    }
    if (destination.trim().isEmpty) return;
    if (hasCall) {
      notice = 'End the current call before starting another call. Join a PBX conference room to talk with multiple participants.';
      notifyListeners();
      return;
    }
    try {
      _call = await account.call(destination.trim());
      activePeer = destination.trim();
      isOutgoing = true;
      callState = CallState.calling;
      latestStats = null;
      notice = '';
      notifyListeners();
    } on MedutException catch (e) {
      notice = 'Call failed: ${e.message ?? e.code}';
      notifyListeners();
    }
  }

  Future<void> answer() async {
    final call = _call;
    if (call == null) return;
    try {
      await call.answer();
    } on MedutException catch (e) {
      notice = 'Could not answer: ${e.message ?? e.code}';
      notifyListeners();
    }
  }

  Future<void> decline() async {
    final call = _call;
    if (call == null) return;
    try {
      await call.reject(statusCode: 603, reason: 'Decline');
    } catch (_) {
      await call.hangup();
    }
  }

  Future<void> hangup() async {
    final call = _call;
    if (call == null) return;
    try {
      if (isRecording) await stopRecording();
      await call.hangup();
    } on MedutException catch (e) {
      notice = 'Hang up failed: ${e.message ?? e.code}';
      notifyListeners();
    }
  }

  Future<void> toggleHold() async {
    final call = _call;
    if (call == null) return;
    try {
      if (isHeld) {
        await call.resume();
      } else {
        await call.hold();
      }
      isHeld = !isHeld;
      notifyListeners();
    } catch (e) {
      notice = 'Hold/resume failed: $e';
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    final call = _call;
    if (call == null) return;
    try {
      await call.mute(on: !isMuted);
      isMuted = !isMuted;
      notifyListeners();
    } catch (e) {
      notice = 'Mute failed: $e';
      notifyListeners();
    }
  }

  Future<void> toggleSpeaker() async {
    final sdk = _sdk;
    if (sdk == null) return;
    try {
      if (!Platform.isAndroid) {
        notice = 'On Windows, choose your microphone and speaker in Settings → Audio devices.';
        notifyListeners();
        return;
      }
      await sdk.setSpeakerphone(!isSpeaker);
      isSpeaker = !isSpeaker;
      notifyListeners();
    } catch (e) {
      notice = 'Audio route change failed: $e';
      notifyListeners();
    }
  }

  Future<void> refreshAudioDevices() async {
    if (!Platform.isWindows || _sdk == null) return;
    try {
      inputDevices = await _sdk!.listInputDevices();
      outputDevices = await _sdk!.listOutputDevices();
      if (selectedInputDevice == null && inputDevices.isNotEmpty) {
        selectedInputDevice = inputDevices.firstWhere((d) => d.isDefault, orElse: () => inputDevices.first).name;
      }
      if (selectedOutputDevice == null && outputDevices.isNotEmpty) {
        selectedOutputDevice = outputDevices.firstWhere((d) => d.isDefault, orElse: () => outputDevices.first).name;
      }
    } catch (e) {
      notice = 'Could not list audio devices: $e';
    }
    notifyListeners();
  }

  Future<void> selectInputDevice(String? name) async {
    if (_sdk == null) return;
    try {
      await _sdk!.setInputDevice(name);
      selectedInputDevice = name;
    } catch (e) {
      notice = 'Could not select microphone: $e';
    }
    notifyListeners();
  }

  Future<void> selectOutputDevice(String? name) async {
    if (_sdk == null) return;
    try {
      await _sdk!.setOutputDevice(name);
      selectedOutputDevice = name;
    } catch (e) {
      notice = 'Could not select speaker: $e';
    }
    notifyListeners();
  }

  Future<void> sendDtmf(String digit) async {
    try {
      await _call?.sendDtmf(digit);
    } catch (e) {
      notice = 'DTMF failed: $e';
      notifyListeners();
    }
  }

  Future<void> blindTransfer(String target) async {
    if (_call == null || target.trim().isEmpty) return;
    try {
      await _call!.transfer(target.trim());
      notice = 'Transfer request sent.';
    } catch (e) {
      notice = 'Transfer failed: $e';
    }
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    if (_call == null) return;
    if (isRecording) {
      await stopRecording();
      return;
    }
    try {
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory('${root.path}${Platform.pathSeparator}Shadow-SIP${Platform.pathSeparator}Recordings');
      await folder.create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final safePeer = activePeer.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      recordingPath = '${folder.path}${Platform.pathSeparator}${safePeer}_$stamp.wav';
      await _call!.recordStart(recordingPath);
      isRecording = true;
      notice = 'Recording started.';
    } catch (e) {
      notice = 'Recording could not start: $e';
    }
    notifyListeners();
  }

  Future<void> stopRecording() async {
    try {
      await _call?.recordStop();
      if (recordingPath.isNotEmpty) notice = 'Recording saved: $recordingPath';
    } catch (e) {
      notice = 'Could not stop recording: $e';
    }
    isRecording = false;
    notifyListeners();
  }

  Future<void> addContact(PhoneContact contact) async {
    contacts = [...contacts, contact]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _dataStore.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> removeContact(PhoneContact contact) async {
    contacts = contacts.where((c) => c != contact).toList();
    await _dataStore.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _dataStore.clearHistory();
    history = [];
    notifyListeners();
  }

  void _handleEvent(MedutEvent event) {
    switch (event) {
      case RegStateEvent e:
        registrationState = e.state;
        registrationMessage = switch (e.state) {
          RegState.registered => 'Registered',
          RegState.registering => 'Registering…',
          RegState.reconnecting => e.retryAttempt > 0
              ? 'Reconnecting · attempt ${e.retryAttempt}'
              : 'Reconnecting…',
          RegState.failed => e.errorStr ?? e.error.name,
          RegState.unregistering => 'Unregistering…',
          RegState.unregistered => 'Not registered',
        };
        break;
      case IncomingCallEvent e:
        _call = e.call;
        activePeer = e.displayName ?? e.fromUri;
        isOutgoing = false;
        callState = CallState.ringing;
        latestStats = null;
        isMuted = false;
        isHeld = false;
        notice = 'Incoming call';
        break;
      case CallStateEvent e:
        if (_call?.id == e.call.id) {
          callState = e.state;
          if (e.state == CallState.established) {
            isHeld = false;
            _startDurationTimer();
            notice = 'Call connected';
          } else if (e.state == CallState.held) {
            isHeld = true;
          } else if (e.state.isTerminal) {
            final endedAt = callStartedAt ?? DateTime.now();
            final endedDuration = callDuration;
            unawaited(_saveFinishedCall(e.call, e.reason ?? e.state.name, endedAt, endedDuration));
            _stopDurationTimer();
            _call = null;
            callState = null;
            latestStats = null;
            isMuted = false;
            isHeld = false;
            isSpeaker = false;
            isRecording = false;
            notice = e.reason ?? 'Call ended';
          }
        }
        break;
      case MediaStatsEvent e:
        latestStats = e.stats;
        break;
      case QualityAlertEvent e:
        if (!e.recovering) {
          notice = 'Audio quality warning: ${e.issue.name} ${e.value.toStringAsFixed(1)}';
        }
        break;
      case TransferFailedEvent e:
        notice = 'Transfer failed: ${e.reason}';
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> _saveFinishedCall(Call call, String result, DateTime endedAt, Duration endedDuration) async {
    final info = await call.info();
    final log = CallLogItem(
      peer: info?.peerDisplayName.isNotEmpty == true
          ? info!.peerDisplayName
          : (info?.peerUri.isNotEmpty == true ? info!.peerUri : activePeer),
      outgoing: call.isOutgoing,
      startedAt: endedAt,
      durationSeconds: info?.duration.inSeconds ?? endedDuration.inSeconds,
      result: result,
    );
    await _dataStore.addHistory(log);
    history = await _dataStore.loadHistory();
    notifyListeners();
  }

  void _startDurationTimer() {
    if (_durationTicker != null) return;
    callStartedAt ??= DateTime.now();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = callStartedAt;
      if (start != null) callDuration = DateTime.now().difference(start);
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTicker?.cancel();
    _durationTicker = null;
    callStartedAt = null;
    callDuration = Duration.zero;
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _events?.cancel();
    _sdk?.detach();
    super.dispose();
  }
}
