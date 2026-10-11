import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 갤러리 사진 고르기: 안드로이드 기본 '사진 선택기'를 쓴다. 권한 없이도 모든 사진·앨범이 보인다.
  // (이걸 안 켜면 '최근 파일' 화면이 떠서 사진이 거의 안 보인다)
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;
  final settings = await Settings.load();
  runApp(TabGameApp(settings: settings));
}
