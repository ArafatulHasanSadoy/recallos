import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// The lock in front of the wallet.
///
/// A phone is the least private object most people own — it is handed over to
/// show a photo, left on a desk, borrowed to make a call. RecallOS keeps every
/// number, address and note someone has collected in one place, offline, with
/// nothing between it and whoever is holding the phone. This is that
/// something.
///
/// Thin on purpose. The prompt belongs to the OS, the comparison happens in the
/// secure enclave, and what comes back here is a boolean — no fingerprint, no
/// face, no template ever reaches this process, which is exactly why this is
/// the right mechanism for an app that promises to keep things on the device.
final appLockProvider = Provider<AppLock>((Ref ref) => AppLock());

/// Why the lock cannot be armed on this phone.
enum LockUnavailable {
  /// No screen lock is set at all — no PIN, no pattern, no fingerprint. There
  /// is nothing to authenticate against, and enrolling one is a decision for
  /// the phone's owner to make in Settings, not something an app can do.
  noScreenLock,

  /// The platform refused to say. Treated as unavailable rather than assumed
  /// working: a lock that cannot be opened is worse than no lock.
  unknown,
}

/// The outcome of asking the user to prove who they are.
enum UnlockResult {
  /// Proven. The wallet opens.
  unlocked,

  /// The prompt was dismissed, or the finger did not match. Ordinary, and
  /// says nothing worth showing — the lock screen simply stays up.
  refused,

  /// Too many failed attempts; the OS has stopped accepting biometrics for
  /// now. The device PIN still works, and the screen says so.
  lockedOut,

  /// Something on the device went wrong. Distinguished from [refused] because
  /// a person who did nothing wrong deserves to be told that.
  failed,
}

/// Wraps the platform's authentication, in the vocabulary the screens use.
class AppLock {
  AppLock({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// The channel `MainActivity` answers. One method, one intent.
  static const MethodChannel _system = MethodChannel(
    'recallos/system_settings',
  );

  /// Opens the phone's own security settings, where a screen lock is set.
  ///
  /// The app cannot set one — that is the phone owner's decision, made in the
  /// OS. What it can do is not be a dead end. Without this the lock row is a
  /// switch that does nothing when tapped, with the reason in grey text
  /// underneath, and a working feature reads as a broken one.
  Future<bool> openSecuritySettings() async {
    try {
      return await _system.invokeMethod<bool>('openSecuritySettings') ?? false;
    } on Object {
      return false;
    }
  }

  /// Whether this phone can be asked to prove who is holding it.
  ///
  /// `isDeviceSupported` rather than `canCheckBiometrics`: a phone with no
  /// fingerprint reader but a PIN can still lock this app, and a great many of
  /// the phones this is aimed at are exactly that. Requiring a fingerprint
  /// would withhold the feature from the users who most need it.
  Future<LockUnavailable?> unavailableReason() async {
    try {
      return await _auth.isDeviceSupported()
          ? null
          : LockUnavailable.noScreenLock;
    } on Object {
      return LockUnavailable.unknown;
    }
  }

  /// Puts the system prompt up and waits for an answer.
  Future<UnlockResult> unlock() async {
    try {
      final bool ok = await _auth.authenticate(
        localizedReason: 'Unlock your wallet',
        // The device PIN is accepted as well as a fingerprint. Not a
        // weakening: a sensor that will not read a wet or worn thumb is a
        // daily occurrence, and an app that locks someone out of their own
        // contacts because of it would simply be uninstalled. The PIN is also
        // what makes the lock work at all on a phone with no reader.
        biometricOnly: false,
        // Survives the OS taking the screen away mid-prompt — a call arriving,
        // the screen timing out — instead of failing and making them start
        // again.
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockResult.unlocked : UnlockResult.refused;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => UnlockResult.refused,
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.temporaryLockout => UnlockResult.lockedOut,
        _ => UnlockResult.failed,
      };
    } on Object {
      return UnlockResult.failed;
    }
  }
}
