import 'package:flutter/material.dart';

import '../../app/session_controller.dart';
import '../../services/error_log_service.dart';
import '../logs/error_logs_screen.dart';
import '../../theme/app_theme.dart';

class ProfileDialog extends StatelessWidget {
  const ProfileDialog({super.key, required this.session, required this.logger});

  final SessionController session;
  final ErrorLogService logger;

  @override
  Widget build(BuildContext context) {
    final user = session.user ?? {};
    final company = session.company ?? {};

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Perfil', style: TextStyle(fontSize: AppFontSize.xl, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Text('Nombre', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4E6070)).copyWith(fontSize: AppFontSize.sm)),
              Text(user['name']?.toString() ?? '-', style: const TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('Email', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4E6070)).copyWith(fontSize: AppFontSize.sm)),
              Text(user['email']?.toString() ?? '-', style: const TextStyle(fontSize: AppFontSize.md)),
              const SizedBox(height: 12),
              Text('Teléfono', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4E6070)).copyWith(fontSize: AppFontSize.sm)),
              Text(user['phone']?.toString() ?? '-', style: const TextStyle(fontSize: AppFontSize.md)),
              const SizedBox(height: 20),
              Text('Empresa', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4E6070)).copyWith(fontSize: AppFontSize.sm)),
              Text(company['name']?.toString() ?? 'Global', style: const TextStyle(fontSize: AppFontSize.md, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ErrorLogsScreen(logger: logger)),
                    );
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Ver logs de errores de hoy'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await session.logout();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
