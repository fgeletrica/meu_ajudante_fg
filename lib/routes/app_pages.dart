import "package:flutter/material.dart";
import "app_routes.dart";

// core
import "../screens/app_entry.dart";
import "../screens/gate_screen.dart";
// auth
import "../screens/auth/login_screen.dart";
import "../screens/auth/register_screen.dart";
// homes
import "../screens/home_screen.dart";
import "../screens/dev_role_screen.dart";
import "../screens/home_client_screen.dart";
import "../screens/home_pro_screen.dart";
// features/screens
import "../features/calc/calc_pro_screen.dart";
import "../screens/calc_screen.dart";
import "../screens/agenda_screen.dart";
import "../screens/orcamentos_screen.dart";
import "../screens/ferramentas_screen.dart";
import "../screens/tutoriais_screen.dart";
import "../screens/account_screen.dart";
import "../screens/paywall_screen.dart";
import "../screens/equipamentos_screen.dart";
import "../screens/clients_screen.dart";
import "../screens/unit_convert_screen.dart";
import "../screens/cable_table_screen.dart";
import "../screens/voltage_drop_screen.dart";
import "../screens/travel_cost_screen.dart";
import "../screens/service_picker_screen.dart";
import "../screens/materials_screen.dart";
import "../screens/community_screen.dart";
import "../screens/services_market_screen.dart";
import "../screens/validate_document_screen.dart";
import "../screens/about_screen.dart";
import "../screens/parceiros_screen.dart";
import "../screens/centro_pro_screen.dart";
// admin (se existir)
import "../features/admin/admin_screen.dart";
class AppPages {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.entry: (_) => const AppEntry(),
        AppRoutes.home: (_) => const GateScreen(),
        // auth
        AppRoutes.authGate: (_) => const GateScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        // homes
        AppRoutes.homePro: (_) => const HomeProScreen(),
        AppRoutes.homeClient: (_) => const HomeClientScreen(),
        AppRoutes.home + "_main": (_) => const HomeScreen(), // compat
        // ferramentas principais
        AppRoutes.calc: (_) => const CalcScreen(),
        AppRoutes.agenda: (_) => const AgendaScreen(),
        AppRoutes.orcamentos: (_) => OrcamentosScreen(),
        AppRoutes.ferramentas: (_) => const FerramentasScreen(),
        AppRoutes.materiais: (_) => MaterialsScreen(),
        AppRoutes.tutoriais: (_) => const TutoriaisScreen(),
        // conta/pro
        AppRoutes.conta: (_) => AccountScreen(),
        AppRoutes.paywall: (_) => PaywallScreen(),
        AppRoutes.validateDoc: (_) => const ValidateDocumentScreen(),
        // extras
        AppRoutes.equipamentos: (_) => const EquipamentosScreen(),
        AppRoutes.clientes: (_) => const ClientsScreen(),
        AppRoutes.unitConvert: (_) => const UnitConvertScreen(),
        AppRoutes.cabosTabela: (_) => const CableTableScreen(),
        AppRoutes.quedaTensao: (_) => const VoltageDropScreen(),
        AppRoutes.deslocamento: (_) => const TravelCostScreen(),
        // social/market
        AppRoutes.parceiros: (_) => const ParceirosScreen(),
        AppRoutes.servicePicker: (_) => const ServicePickerScreen(),
        AppRoutes.marketplace: (_) => const ServicesMarketScreen(),
        AppRoutes.comunidade: (_) => const CommunityScreen(),
        // materiais
        // sobre/centro pro
        "/sobre": (_) => const AboutScreen(),
        "/centro_pro": (_) => const CentroProScreen(),
        // admin
        AppRoutes.admin: (_) => const AdminScreen(),
      };
}
