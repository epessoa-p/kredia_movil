import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/error_log_service.dart';
import '../../services/offline_payment_queue.dart';
import '../../theme/app_theme.dart';
import '../../theme/module_colors.dart';
import '../../utils/api_errors.dart';
import '../../utils/currency.dart';
import '../../utils/number_utils.dart';

/// Préstamo en CUOTAS: resumen, plan de pagos, garantes y cobro (con GPS y cola sin conexión).
class InstallmentLoanScreen extends StatefulWidget {
  const InstallmentLoanScreen({super.key, required this.api, required this.logger, required this.loanId});

  final ApiService api;
  final ErrorLogService logger;
  final int loanId;

  @override
  State<InstallmentLoanScreen> createState() => _InstallmentLoanScreenState();
}

class _InstallmentLoanScreenState extends State<InstallmentLoanScreen> {
  static const _color = ModuleColors.loans;
  final _money = Currency.formatter();
  final _date = DateFormat('dd/MM/yyyy');

  Map<String, dynamic> _loan = {};
  bool _loading = true;
  bool _paying = false;
  String? _error;

  /// Mismo request_id mientras el cobro no se confirme: un reintento no cobra dos veces.
  String _requestId = newRequestId();

  static const _frequencies = {'daily': 'Diario', 'weekly': 'Semanal', 'biweekly': 'Quincenal', 'monthly': 'Mensual'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.installmentLoan(widget.loanId);
      _loan = data['loan'] is Map ? Map<String, dynamic>.from(data['loan']) : {};
    } catch (e, st) {
      if (isUnexpectedApiError(e)) {
        await widget.logger.logError(module: 'installment_loan', error: e, stackTrace: st, endpoint: '/loans/${widget.loanId}/installments');
      }
      _error = apiErrorMessage(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _summary => _loan['summary'] is Map ? Map<String, dynamic>.from(_loan['summary']) : {};

  Future<void> _pay() async {
    final ctrl = TextEditingController(
      text: asDouble(_summary['overdue_amount']) > 0
          ? asDouble(_summary['overdue_amount']).toStringAsFixed(2)
          : asDouble(_summary['next_due_amount']).toStringAsFixed(2),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar cobro'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Monto', prefixText: Currency.prefix),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.success),
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
            child: const Text('Cobrar'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _paying = true);
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    try {
      await widget.api.payInstallments(
        loanId: widget.loanId,
        amount: amount,
        requestId: _requestId,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
      _requestId = newRequestId();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cobro de ${_money.format(amount)} registrado.'),
          backgroundColor: AppPalette.success,
        ));
      }
      await _load();
    } catch (e, st) {
      if (OfflinePaymentQueue.isOfflineError(e)) {
        await OfflinePaymentQueue.instance.add(PendingPayment(
          requestId: _requestId,
          loanId: widget.loanId,
          loanCode: _loan['code']?.toString() ?? '',
          clientName: (_loan['client'] is Map ? _loan['client']['name'] : '')?.toString() ?? '',
          amount: amount,
          paymentMethod: 'efectivo',
          createdAt: DateTime.now(),
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        ));
        _requestId = newRequestId();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión: el cobro quedó guardado y se enviará desde "Cobranza del día".'),
            backgroundColor: AppPalette.warning,
          ));
        }
      } else {
        if (isUnexpectedApiError(e)) {
          await widget.logger.logError(module: 'installment_loan', error: e, stackTrace: st, endpoint: '/loans/${widget.loanId}/installment-payments');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppPalette.danger));
        }
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final installments = (_loan['installments'] as List?)?.whereType<Map>().toList() ?? [];
    final guarantors = (_loan['guarantors'] as List?)?.whereType<Map>().toList() ?? [];
    final client = _loan['client'] is Map ? _loan['client'] as Map : const {};
    final open = _loan['status'] == 'ACTIVO' || _loan['status'] == 'EN_MORA';

    return Scaffold(
      appBar: AppBar(
        title: Text(_loan['code']?.toString() ?? 'Préstamo'),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      backgroundColor: AppPalette.background,
      floatingActionButton: open
          ? FloatingActionButton.extended(
              onPressed: _paying ? null : _pay,
              backgroundColor: AppPalette.success,
              foregroundColor: Colors.white,
              icon: _paying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments_rounded),
              label: const Text('Cobrar'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: text.bodyMedium)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text(client['name']?.toString() ?? '', style: text.titleMedium),
                      Text(
                        '${_frequencies[_loan['payment_frequency']] ?? ''} · ${_loan['installments_count']} cuotas de '
                        '${_money.format(asDouble(_loan['installment_amount']))} · ${asDouble(_loan['interest_rate'])}% mensual',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _kpi('Pendiente', _money.format(asDouble(_summary['outstanding'])), _color)),
                        const SizedBox(width: 8),
                        Expanded(child: _kpi('Vencido', _money.format(asDouble(_summary['overdue_amount'])),
                            asDouble(_summary['overdue_amount']) > 0 ? AppPalette.danger : AppPalette.success)),
                      ]),
                      const SizedBox(height: 16),
                      Text('Plan de pagos', style: text.titleSmall),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(children: [
                          for (final i in installments)
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: ModuleColors.soft(_statusColor(i)),
                                child: Text('${i['number']}', style: text.labelSmall?.copyWith(color: _statusColor(i))),
                              ),
                              title: Text(_date.format(DateTime.parse(i['due_date'].toString())), style: text.bodyMedium),
                              subtitle: asInt(i['days_late']) > 0
                                  ? Text('${i['days_late']} días de atraso', style: text.bodySmall?.copyWith(color: AppPalette.danger))
                                  : null,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_money.format(asDouble(i['amount']) + asDouble(i['penalty'])), style: text.titleSmall),
                                  Text(i['status'] == 'paid' ? 'Pagada' : 'Falta ${_money.format(asDouble(i['pending']))}',
                                      style: text.bodySmall?.copyWith(color: _statusColor(i))),
                                ],
                              ),
                            ),
                        ]),
                      ),
                      if (guarantors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Garantes', style: text.titleSmall),
                        const SizedBox(height: 8),
                        for (final g in guarantors)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.verified_user_rounded),
                              title: Text(g['name']?.toString() ?? ''),
                              subtitle: Text([g['id_number'], g['phone'], g['relationship']].where((v) => v != null && '$v'.isNotEmpty).join(' · ')),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Color _statusColor(Map i) {
    if (i['status'] == 'paid') return AppPalette.success;
    if (asInt(i['days_late']) > 0) return AppPalette.danger;
    if (i['status'] == 'partial') return AppPalette.warning;
    return AppPalette.textMuted;
  }

  Widget _kpi(String label, String value, Color color) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: text.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: text.titleMedium?.copyWith(color: color)),
        ]),
      ),
    );
  }
}
