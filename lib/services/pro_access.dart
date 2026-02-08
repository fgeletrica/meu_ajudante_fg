import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProAccess {
  static const _kProDev = 'pro_dev';
  static const _kTrialUntilMs = 'pro_trial_until_ms';

  static Future<bool> getProDev() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kProDev) ?? false;
  }

  static Future<void> setProDev(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProDev, v);
  }

  static Future<int> getTrialUntilMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTrialUntilMs) ?? 0;
  }

  static Future<void> startTrial({required Duration duration}) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(duration).millisecondsSinceEpoch;
    await prefs.setInt(_kTrialUntilMs, until);
  }

  static Future<void> resetTrial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTrialUntilMs);
  }

  static Future<Duration> trialRemaining() async {
    final until = await getTrialUntilMs();
    if (until <= 0) return Duration.zero;
    final leftMs = until - DateTime.now().millisecondsSinceEpoch;
    if (leftMs <= 0) return Duration.zero;
    return Duration(milliseconds: leftMs);
  }

  static String formatDuration(Duration d) {
    final total = d.inSeconds;
    if (total <= 0) return '0s';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  static Future<bool> hasProAccessNow() async {
    // modo dev liga PRO sempre
    final dev = await getProDev();
    if (dev) return true;

    // trial
    final left = await trialRemaining();
    return left > Duration.zero;
  }

  static Future<void> openPaywall(BuildContext context) async {
    try {
      await Navigator.of(context).pushNamed('/paywall');
    } catch (_) {}
  }
}
