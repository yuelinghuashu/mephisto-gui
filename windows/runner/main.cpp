#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // 统一桌面端默认窗口尺寸（与 Linux / macOS 一致）。
  Win32Window::Size size(1280, 720);

  // 窗口默认位置：水平 + 垂直居中于主屏幕。
  // 使用 GetSystemMetrics 获取屏幕工作区尺寸，origin = (屏幕 - 窗口) / 2。
  const int screen_width = ::GetSystemMetrics(SM_CXSCREEN);
  const int screen_height = ::GetSystemMetrics(SM_CYSCREEN);
  const int origin_x = (screen_width - size.width) / 2;
  const int origin_y = (screen_height - size.height) / 2;
  // 极端情况（屏幕小于窗口）时避免负数坐标导致窗口跑到屏幕外
  const Win32Window::Point origin(
      origin_x > 0 ? origin_x : 0, origin_y > 0 ? origin_y : 0);

  if (!window.Create(L"Mephisto", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
