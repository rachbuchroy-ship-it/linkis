import 'package:flutter/material.dart';

import 'package:linkis/theme_controller.dart';
// or whatever file contains ThemeController, AppThemeId, AppThemes

class SettingsScreen extends StatelessWidget {
  final ThemeController controller;

  const SettingsScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.themeId;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your design',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: AppThemeId.values.map((id) {
                      final spec = AppThemes.spec(id);
                      final selected = id == current;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => controller.setTheme(id),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: spec.tile,
                              border: Border.all(
                                color: selected
                                    ? spec.tileGlow
                                    : spec.tileBorder,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: spec.tileGlow.withOpacity(
                                    selected ? 0.28 : 0.12,
                                  ),
                                  blurRadius: selected ? 22 : 14,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: spec.background,
                                    border: Border.all(
                                      color: spec.tileBorder,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    spec.displayName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: spec.onTile,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle,
                                    color: spec.tileGlow,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}