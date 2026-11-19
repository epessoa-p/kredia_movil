import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Cobro guardado en el celular cuando no había conexión.
class PendingPayment {
  PendingPayment({
    required this.requestId,
    required this.loanId,
    required this.loanCode,
    required this.clientName,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.lastError,
  });

  final String requestId;
  final int loanId;
  final String loanCode;
  final String clientName;
  final double amount;
  final String paymentMethod;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  String? lastError;

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'loan_id': loanId,
        'loan_code': loanCode,
        'client_name': clientName,
        'amount': amount,
        'payment_method': paymentMethod,
        'created_at': createdAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'last_error': lastError,
      };

  factory PendingPayment.fromJson(Map<String, dynamic> j) => PendingPayment(
        requestId: j['request_id'].toString(),
        loanId: (j['loan_id'] as num).toInt(),
        loanCode: j['loan_code']?.toString() ?? '',
        clientName: j['client_name']?.toString() ?? '',
        amount: (j['amount'] as num).toDouble(),
        paymentMethod: j['payment_method']?.toString() ?? 'efectivo',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        lastError: j['last_error']?.toString(),
      );
}

/// Cola de cobros sin conexión.
///
/// El cobrador puede registrar un cobro aunque no tenga señal: queda guardado en el celular
/// con su `request_id` y se envía cuando vuelve la conexión. Como el servidor es idempotente
/// por `request_id`, reenviar un cobro que sí había llegado NO lo cobra dos veces.
class OfflinePaymentQueue {
  OfflinePaymentQueue._();
  static final OfflinePaymentQueue instance = OfflinePaymentQueue._();

  static const _key = 'offline_payments_v1';

  Future<List<PendingPayment>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw);
    return list is List ? list.whereType<Map>().map((m) => PendingPayment.fromJson(Map<String, dynamic>.from(m))).toList() : [];
  }

  Future<int> count() async => (await all()).length;

  Future<void> add(PendingPayment payment) async {
    final items = await all();
    if (items.any((p) => p.requestId == payment.requestId)) return;
    items.add(payment);
    await _save(items);
  }

  Future<void> _save(List<PendingPayment> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((p) => p.toJson()).toList()));
  }

  /// true si el error es de red (sin respuesta del servidor): el cobro debe quedar en cola.
  static bool isOfflineError(Object error) =>
      error is DioException &&
      error.response == null &&
      (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.unknown);

  /// Envía los cobros pendientes. Devuelve (enviados, que quedan).
  /// Los que el servidor RECHAZA (422: monto mayor a la deuda, caja cerrada…) quedan con su error
  /// para que el cobrador los revise; los de red se reintentan la próxima vez.
  Future<({int sent, int remaining})> sync(ApiService api) async {
    final items = await all();
    if (items.isEmpty) return (sent: 0, remaining: 0);

    var sent = 0;
    final keep = <PendingPayment>[];
    for (final p in items) {
      try {
        await api.payInstallments(
          loanId: p.loanId,
          amount: p.amount,
          requestId: p.requestId,
          paymentMethod: p.paymentMethod,
          latitude: p.latitude,
          longitude: p.longitude,
          paidAt: p.createdAt,
        );
        sent++;
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 409) {
          sent++; // ya estaba procesado
          continue;
        }
        if (!isOfflineError(e)) {
          final data = e is DioException ? e.response?.data : null;
          p.lastError = data is Map && data['message'] != null ? data['message'].toString() : 'No se pudo registrar.';
        }
        keep.add(p);
      }
    }
    await _save(keep);
    return (sent: sent, remaining: keep.length);
  }

  Future<void> remove(String requestId) async {
    final items = await all();
    items.removeWhere((p) => p.requestId == requestId);
    await _save(items);
  }
}
