import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initSqflite() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('[db] using sqflite_common_ffi (desktop)');
  } else {
    debugPrint('[db] using native sqflite (mobile)');
  }
}
