import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const UiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withOpacity(.35).withOpacity(.35)),
      ),
      child: child,
    );
  }
}

class UiBtn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  const UiBtn({super.key, required this.text, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
