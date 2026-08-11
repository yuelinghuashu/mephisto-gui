import 'app/main.dart' as app;

/// 统一应用入口（转发至 lib/app/main.dart）
///
/// Flutter 工具链默认查找 `lib/main.dart` 作为构建入口；
/// 本转发文件让 `flutter build linux/macos/windows/android/ios`
/// 无需显式 `-t` 参数即可找到真实入口 [app.main]。
void main() => app.main();
