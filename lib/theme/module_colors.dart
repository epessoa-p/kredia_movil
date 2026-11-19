import 'package:flutter/material.dart';

/// Color de cada módulo (el MISMO que la web: kredia_web/config/menu.php y kredia-ui.css).
/// El color ayuda a reconocer el proceso de un vistazo: préstamos violeta, clientes cian, etc.
class ModuleColors {
  static const Color dashboard = Color(0xFF2563EB);
  static const Color loans = Color(0xFF7C3AED);
  static const Color collections = Color(0xFFDB2777);
  static const Color clients = Color(0xFF0891B2);
  static const Color cash = Color(0xFF16A34A);
  static const Color inventory = Color(0xFFEA580C);
  static const Color sales = Color(0xFFCA8A04);
  static const Color purchases = Color(0xFFDC2626);
  static const Color catalogs = Color(0xFF0D9488);
  static const Color reports = Color(0xFF4F46E5);
  static const Color capital = Color(0xFF059669);
  static const Color admin = Color(0xFF475569);

  /// Fondo suave del módulo (10 %), para íconos en cuadrito y chips.
  static Color soft(Color color) => Color.alphaBlend(color.withValues(alpha: 0.10), Colors.white);
}
