import package:flutter/material.dart;
import package:meu_ajudante_fg/routes/app_routes.dart;

// Screens
import ../screens/home_screen.dart;
import ../screens/calc_screen.dart;
import ../screens/agenda_screen.dart;
import ../screens/orcamentos_screen.dart;
import ../screens/ferramentas_screen.dart;
import ../screens/tutoriais_screen.dart;
import ../screens/account_screen.dart;
import ../screens/paywall_screen.dart;
import ../screens/equipamentos_screen.dart;
import ../screens/clients_screen.dart;
import ../screens/unit_convert_screen.dart;
import ../screens/cable_table_screen.dart;
import ../screens/voltage_drop_screen.dart;
import ../screens/travel_cost_screen.dart;
import ../screens/travel_cost_screen.dart;
import ../screens/service_picker_screen.dart;
import ../screens/materials_screen.dart;

import ../screens/about_screen.dart;
import ../screens/parceiros_screen.dart;
import ../screens/centro_pro_screen.dart;

import ../features/admin/admin_screen.dart;
import ../screens/gate_screen.dart;

import ../screens/app_entry.dart;
import ../screens/auth/auth_gate_screen.dart;
import ../screens/auth/login_screen.dart;
import ../screens/auth/register_screen.dart;
import ../screens/home_client_screen.dart;
import ../screens/home_pro_screen.dart;
import ../screens/community_screen.dart;
import ../screens/services_market_screen.dart;
import ../screens/validate_document_screen.dart;

class AppPages {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.validateDoc: (_) => const ValidateDocumentScreen(),

        AppRoutes.homePro: (_) => const HomeProScreen(),
        AppRoutes.homeClient: (_) => const HomeClientScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.authGate: (_) => const AuthGateScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.entry: (_) => const AppEntry(),
        AppRoutes.homeMain: (_) => const HomeScreen(),
        AppRoutes.home: (_) => const GateScreen(),

        AppRoutes.calc: (_) => const CalcScreen(),
        AppRoutes.materiais: (_) => MaterialsScreen(),
        AppRoutes.agenda: (_) => const AgendaScreen(),
        AppRoutes.orcamentos: (_) => OrcamentosScreen(),
        AppRoutes.ferramentas: (_) => const FerramentasScreen(),
        AppRoutes.tutoriais: (_) => const TutoriaisScreen(),

        AppRoutes.conta: (_) => AccountScreen(),
        AppRoutes.paywall: (_) => PaywallScreen(),
        AppRoutes.equipamentos: (_) => const EquipamentosScreen(),
        AppRoutes.clientes: (_) => const ClientsScreen(),
        AppRoutes.unitConvert: (_) => const UnitConvertScreen(),
        AppRoutes.cabosTabela: (_) => const CableTableScreen(),
        AppRoutes.quedaTensao: (_) => const VoltageDropScreen(),
        AppRoutes.deslocamento: (_) => const TravelCostScreen(),
        AppRoutes.parceiros: (_) => const ParceirosScreen(),
        AppRoutes.servicePicker: (_) => const ServicePickerScreen(),
        AppRoutes.marketplace: (_) => const ServicesMarketScreen(),
        AppRoutes.comunidade: (_) => const CommunityScreen(),

        "/sobre": (_) => const AboutScreen(),
        "/centro_pro": (_) => const CentroProScreen(),
        AppRoutes.admin: (_) => const AdminScreen(),
      };
}
