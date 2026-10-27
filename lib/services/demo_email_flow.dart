/// UI-only email simulator. It never sends mail, calls APIs, or stores passwords.
/// Backend integration must replace this adapter, including authoritative expiry,
/// resend limits, verification state, credential updates, and email delivery.
enum EmailPurpose { verification, passwordReset }

enum DemoEmailFailure { invalidCode, expiredCode, locked, cooldown }

class _Challenge {
  _Challenge(this.created);
  final DateTime created;
  int attempts = 0;
  bool used = false;
}

class DemoEmailFlow {
  DemoEmailFlow({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static const code = '123456';
  static const expiry = Duration(minutes: 15);
  static const resendDelay = Duration(seconds: 60);
  final DateTime Function() _now;
  final Map<(String, EmailPurpose), _Challenge> _challenges = {};
  (String, EmailPurpose) _key(String email, EmailPurpose purpose) =>
      (email.trim().toLowerCase(), purpose);

  int resendSeconds(String email, EmailPurpose purpose) {
    final c = _challenges[_key(email, purpose)];
    if (c == null) return 0;
    final milliseconds =
        c.created.add(resendDelay).difference(_now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  Future<void> requestCode(String email, EmailPurpose purpose) async {
    if (resendSeconds(email, purpose) > 0) throw DemoEmailFailure.cooldown;
    _challenges[_key(email, purpose)] = _Challenge(_now());
  }

  Future<void> confirmCode(
      String email, EmailPurpose purpose, String value) async {
    final c = _challenges[_key(email, purpose)];
    if (c == null || c.used) throw DemoEmailFailure.invalidCode;
    if (!_now().isBefore(c.created.add(expiry))) {
      throw DemoEmailFailure.expiredCode;
    }
    if (c.attempts >= 5) throw DemoEmailFailure.locked;
    if (value.trim() != code) {
      c.attempts++;
      throw c.attempts >= 5
          ? DemoEmailFailure.locked
          : DemoEmailFailure.invalidCode;
    }
    c.used = true;
  }
}
