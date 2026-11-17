import 'dart:io';

import 'package:flutter/services.dart';

/// One-shot Android gallery picker for video.
///
/// It uses the system Photo Picker on Android 13+ and falls back to
/// ACTION_GET_CONTENT elsewhere. The picked URI is copied into the app cache
/// and the grant is not persisted, so a later launch cannot silently reuse an
/// old path. Audio deliberately does not use this channel: audio stays in the
/// document picker.
class GalleryPicker {
  static const MethodChannel _channel = MethodChannel('reencode/gallery');

  static Future<String?> pickVideo() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickVideo');
    } catch (_) {
      return null;
    }
  }
}
