import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/storage/preferences_service.dart';

class CustomThemeState {
  final ThemeMode mode;
  final AppThemePreset preset;
  final AppBackgroundStyle bgStyle;

  const CustomThemeState({
    required this.mode,
    required this.preset,
    this.bgStyle = AppBackgroundStyle.standard,
  });

  CustomThemeState copyWith({
    ThemeMode? mode,
    AppThemePreset? preset,
    AppBackgroundStyle? bgStyle,
  }) {
    return CustomThemeState(
      mode: mode ?? this.mode,
      preset: preset ?? this.preset,
      bgStyle: bgStyle ?? this.bgStyle,
    );
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, CustomThemeState>(
  (ref) => ThemeNotifier(),
);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref),
);

class ThemeNotifier extends StateNotifier<CustomThemeState> {
  ThemeNotifier()
      : super(const CustomThemeState(
          mode: ThemeMode.light,
          preset: AppThemePreset.emerald,
          bgStyle: AppBackgroundStyle.standard,
        )) {
    _load();
  }

  void _load() {
    final modeName = PreferencesService.get<String>('themeMode');
    ThemeMode mode;
    if (modeName == 'dark') {
      mode = ThemeMode.dark;
    } else if (modeName == 'light') {
      mode = ThemeMode.light;
    } else if (modeName == 'system') {
      mode = ThemeMode.system;
    } else {
      final isDarkLegacy = PreferencesService.get<bool>('isDarkMode') ?? false;
      mode = isDarkLegacy ? ThemeMode.dark : ThemeMode.light;
    }

    final presetIndex = PreferencesService.get<int>('themePresetIndex') ?? 0;
    final preset = (presetIndex >= 0 && presetIndex < AppThemePreset.values.length)
        ? AppThemePreset.values[presetIndex]
        : AppThemePreset.emerald;

    final bgIndex = PreferencesService.get<int>('themeBgStyleIndex') ?? 0;
    final bgStyle = (bgIndex >= 0 && bgIndex < AppBackgroundStyle.values.length)
        ? AppBackgroundStyle.values[bgIndex]
        : AppBackgroundStyle.standard;

    state = CustomThemeState(mode: mode, preset: preset, bgStyle: bgStyle);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    String val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.system) val = 'system';
    await PreferencesService.set('themeMode', val);
    await PreferencesService.set('isDarkMode', mode == ThemeMode.dark);
  }

  Future<void> setPreset(AppThemePreset preset) async {
    state = state.copyWith(preset: preset);
    await PreferencesService.set('themePresetIndex', preset.index);
  }

  Future<void> setBgStyle(AppBackgroundStyle bgStyle) async {
    state = state.copyWith(bgStyle: bgStyle);
    await PreferencesService.set('themeBgStyleIndex', bgStyle.index);
  }

  Future<void> toggleMode() async {
    final next = state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(ThemeMode.light) {
    _ref.listen<CustomThemeState>(themeProvider, (_, next) {
      state = next.mode;
    });
    state = _ref.read(themeProvider).mode;
  }

  Future<void> toggle() async {
    await _ref.read(themeProvider.notifier).toggleMode();
  }

  bool get isDark => state == ThemeMode.dark;
}
