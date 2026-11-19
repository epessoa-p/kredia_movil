import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/error_log_service.dart';
import '../../services/offline_payment_queue.dart';
import '../../theme/app_theme.dart';
import '../../theme/module_colors.dart';
import '../../utils/api_errors.dart';
import '../../utils/currency.dart';
import '../../utils/number_utils.dart';

/// Cobranza del día: clientes con cuotas que vencen hoy o atrasadas, en el orden de la ruta.
///
/// - Al cobrar se guarda la ubicación GPS del cobro (si el permiso está dado).
/// - Sin conexión, el cobro queda en el celular y se envía después (idempotente por request_id).
class CobranzaScreen extends StatefulWidget {
  const CobranzaScreen({super.key, required this.api, required this.logger});

  final ApiService api;
  final ErrorLogService logger;

  @override
  State<CobranzaScreen> createState() => _CobranzaScreenState();
}

class _CobranzaScreenState extends State<CobranzaScreen> {
  static const _color = ModuleColors.collections;
  final _money = Currency.formatter();
  final _queue = OfflinePaymentQueue.instance;

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _totals = {};
  List<PendingPayment> _pending = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _sync(silent: true);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.collectionsToday();
      final items = data['items'];
      _items = items is List ? items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
      _totals = data['totals'] is Map ? Map<String, dynamic>.from(data['totals']) : {};
    } catch (e, st) {
      if (isUnexpectedApiError(e)) {
        await widget.logger.logError(module: 'cobranza', error: e, stackTrace: st, endpoint: '/collections/today');
      }
      _error = OfflinePaymentQueue.isOfflineError(e)
          ? 'Sin conexión. Puedes seguir cobrando: los cobros se envían al volver la señal.'
          : apiErrorMessage(e);
    } finally {
      _pending = await _queue.all();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync({bool silent = false}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await _queue.sync(widget.api);
      _pending = await _queue.all();
      if (!silent && mounted) {
        final msg = result.sent > 0
            ? '${result.sent} cobro(s) enviados.${result.remaining > 0 ? ' Quedan ${result.remaining}.' : ''}'
            : (result.remaining > 0 ? 'Aún sin conexión: ${result.remaining} cobro(s) pendientes.' : 'No hay cobros pendientes.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Ubicación actual con tiempo límite corto: si no hay GPS, el cobro sigue sin ubicación.
  Future<Position?> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _collect(Map<String, dynamic> item) async {
    final result = await showModalBottomSheet<({double amount, String method})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(item: item, money: _money),
    );
    if (result == null || !mounted) return;

    final requestId = newRequestId();
    final loanId = asInt(item['loan_id']);
    final client = item['client'] is Map ? Map<String, dynamic>.from(item['client']) : <String, dynamic>{};
    final pos = await _position();

    try {
      await widget.api.payInstallments(
        loanId: loanId,
        amount: result.amount,
        requestId: requestId,
        paymentMethod: result.method,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cobro de ${_money.format(result.amount)} registrado.'),
          backgroundColor: AppPalette.success,
        ));
      }
      await _load();
    } catch (e, st) {
      if (OfflinePaymentQueue.isOfflineError(e)) {
        await _queue.add(PendingPayment(
          requestId: requestId,
          loanId: loanId,
          loanCode: item['code']?.toString() ?? '',
          clientName: client['name']?.toString() ?? '',
          amount: result.amount,
          paymentMethod: result.method,
          createdAt: DateTime.now(),
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        ));
        _pending = await _queue.all();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión: el cobro quedó guardado y se enviará al volver la señal.'),
            backgroundColor: AppPalette.warning,
          ));
        }
        return;
      }
      if (isUnexpectedApiError(e)) {
        await widget.logger.logError(module: 'cobranza', error: e, stackTrace: st, endpoint: '/loans/$loanId/installment-payments');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppPalette.danger));
      }
    }
  }

  Future<void> _openMap(Map<String, dynamic> client) async {
    final lat = client['location_lat'], lng = client['location_lng'];
    if (lat == null || lng == null) return;
    await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) => launchUrl(Uri.parse('tel:$phone'));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranza del día'),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Enviar cobros pendientes',
            onPressed: _syncing ? null : () => _sync(),
            icon: Badge(
              isLabelVisible: _pending.isNotEmpty,
              label: Text('${_pending.length}'),
              child: _syncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
            ),
          ),
        ],
      ),
      backgroundColor: AppPalette.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: _Kpi(label: 'Clientes', value: '${_totals['count'] ?? _items.length}', color: _color)),
              const SizedBox(width: 12),
              Expanded(child: _Kpi(label: 'Por cobrar', value: _money.format(asDouble(_totals['due'])), color: _color)),
            ]),
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: ModuleColors.soft(AppPalette.warning),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_pending.length} cobro(s) sin enviar', style: text.titleSmall),
                    const SizedBox(height: 4),
                    for (final p in _pending)
                      Text(
                        '${p.loanCode} · ${p.clientName} · ${_money.format(p.amount)}${p.lastError != null ? ' — ${p.lastError}' : ''}',
                        style: text.bodySmall?.copyWith(color: p.lastError != null ? AppPalette.danger : null),
                      ),
                  ]),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: text.bodyMedium?.copyWith(color: AppPalette.danger)),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_items.isEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('No hay cobros pendientes para hoy.', style: text.bodyMedium)),
              )
            else
              for (final item in _items) _tile(item, text),
          ],
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> item, TextTheme text) {
    final client = item['client'] is Map ? Map<String, dynamic>.from(item['client']) : <String, dynamic>{};
    final days = asInt(item['max_days_late']);
    final phone = client['phone']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(client['name']?.toString() ?? '', style: text.titleSmall)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ModuleColors.soft(days > 0 ? AppPalette.danger : AppPalette.success),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(days > 0 ? '$days días' : 'Al día',
                  style: text.labelSmall?.copyWith(color: days > 0 ? AppPalette.danger : AppPalette.success)),
            ),
          ]),
          const SizedBox(height: 2),
          Text('${item['code']} · ${client['address'] ?? ''}', style: text.bodySmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cobrar hoy', style: text.labelSmall),
                Text(_money.format(asDouble(item['due_today'])), style: text.titleMedium?.copyWith(color: _color)),
              ]),
            ),
            if (phone != null && phone.isNotEmpty)
              IconButton(tooltip: 'Llamar', onPressed: () => _call(phone), icon: const Icon(Icons.phone_rounded)),
            if (client['location_lat'] != null)
              IconButton(tooltip: 'Cómo llegar', onPressed: () => _openMap(client), icon: const Icon(Icons.directions_rounded)),
            FilledButton.icon(
              onPressed: () => _collect(item),
              style: FilledButton.styleFrom(backgroundColor: AppPalette.success),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Cobrar'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: text.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: text.titleLarge?.copyWith(color: color)),
        ]),
      ),
    );
  }
}

/// Hoja para ingresar el monto del cobro (atajos: cobrar hoy / cuota) y el método.
class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.item, required this.money});

  final Map<String, dynamic> item;
  final dynamic money;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final TextEditingController _amount =
      TextEditingController(text: asDouble(widget.item['due_today']).toStringAsFixed(2));
  String _method = 'efectivo';
  String? _error;

  void _submit() {
    final value = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final max = asDouble(widget.item['outstanding']);
    if (value <= 0) {
      setState(() => _error = 'Ingresa un monto mayor a 0.');
      return;
    }
    if (max > 0 && value > max) {
      setState(() => _error = 'El monto supera la deuda (${widget.money.format(max)}).');
      return;
    }
    Navigator.pop(context, (amount: value, method: _method));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final client = widget.item['client'] is Map ? widget.item['client']['name']?.toString() ?? '' : '';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Cobrar a $client', style: text.titleMedium),
        Text('${widget.item['code']} · Deuda total ${widget.money.format(asDouble(widget.item['outstanding']))}', style: text.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ActionChip(label: Text('Hoy ${widget.money.format(asDouble(widget.item['due_today']))}'),
              onPressed: () => _amount.text = asDouble(widget.item['due_today']).toStringAsFixed(2)),
          ActionChip(label: Text('Cuota ${widget.money.format(asDouble(widget.item['installment_amount']))}'),
              onPressed: () => _amount.text = asDouble(widget.item['installment_amount']).toStringAsFixed(2)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Monto', prefixText: Currency.prefix, errorText: _error),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Método'),
          items: const [
            DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
            DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
            DropdownMenuItem(value: 'qr', child: Text('QR')),
          ],
          onChanged: (v) => setState(() => _method = v ?? 'efectivo'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppPalette.success),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Registrar cobro'),
        ),
      ]),
    );
  }
}
