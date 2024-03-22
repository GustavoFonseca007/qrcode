import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeService {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  ThemeData get LightTheme => ThemeData.light();
  ThemeData get darkTheme => ThemeData.dark();

  ThemeMode getThemeMode() {
    return isDarkMode() ? ThemeMode.dark : ThemeMode.light;
  }

  bool isDarkMode() {
    return _box.read(_key) ?? false;
  }

  void switchTheme() {
    Get.changeThemeMode(isDarkMode() ? ThemeMode.light : ThemeMode.dark);
    _box.write(_key, !isDarkMode());
  }
}
