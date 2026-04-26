import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_settings.dart';

class CurrencyRates {
  final String base;
  final Map<String, double> rates;
  final DateTime fetchedAt;

  const CurrencyRates({
    required this.base,
    required this.rates,
    required this.fetchedAt,
  });

  bool get isStale =>
      DateTime.now().difference(fetchedAt) >= const Duration(hours: 1);

  Map<String, dynamic> toJson() => {
        'base': base,
        'rates': rates,
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
      };

  factory CurrencyRates.fromJson(Map<String, dynamic> json) {
    final ratesRaw = json['rates'] as Map<String, dynamic>;
    return CurrencyRates(
      base: json['base'] as String,
      rates: ratesRaw
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      fetchedAt:
          DateTime.fromMillisecondsSinceEpoch(json['fetched_at'] as int),
    );
  }
}

class CurrencyRepository extends ChangeNotifier {
  static final CurrencyRepository instance = CurrencyRepository._();
  CurrencyRepository._();

  static const String _settingsKey = 'currency_rates';
  static const String _baseUrl =
      'https://api.frankfurter.dev/v1/latest?from=USD';

  CurrencyRates? _cached;
  bool _loading = false;
  String? _lastError;

  CurrencyRates? get rates => _cached;
  bool get loading => _loading;
  String? get lastError => _lastError;

  Future<void> loadCached() async {
    if (_cached != null) return;
    final raw = await AppSettings.instance.get(_settingsKey);
    if (raw == null) return;
    try {
      _cached = CurrencyRates.fromJson(jsonDecode(raw));
      debugPrint(
          '[currency] loaded from cache, ${_cached!.rates.length} rates, fetched=${_cached!.fetchedAt}');
      notifyListeners();
    } catch (e) {
      debugPrint('[currency] cache parse failed: $e');
    }
  }

  Future<CurrencyRates?> ensureFresh() async {
    if (_loading) return _cached;
    await loadCached();
    if (_cached != null && !_cached!.isStale) return _cached;
    return refresh();
  }

  Future<CurrencyRates?> refresh() async {
    if (_loading) return _cached;
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      debugPrint('[currency] GET $_baseUrl');
      final response = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw 'HTTP ${response.statusCode}';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final base = data['base'] as String;
      final ratesRaw = data['rates'] as Map<String, dynamic>;
      final rates = ratesRaw
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      rates[base] = 1.0;
      _cached = CurrencyRates(
        base: base,
        rates: rates,
        fetchedAt: DateTime.now(),
      );
      await AppSettings.instance.set(_settingsKey, jsonEncode(_cached!.toJson()));
      debugPrint('[currency] refreshed ${rates.length} rates');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[currency] fetch FAILED: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
    return _cached;
  }
}
