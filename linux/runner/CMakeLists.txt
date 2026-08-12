cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Install the .desktop file and icon for desktop environment integration.
# 仅当安装前缀指向构建输出 bundle 目录时才安装（本地开发/打包）。
# CI 环境（如 GitHub Actions）没有 /usr/local 写入权限，且 .deb 打包流程已
# 手动生成系统级 .desktop 与图标，此处跳过以避免 Permission denied。
if(CMAKE_INSTALL_PREFIX MATCHES "bundle$")
  install(FILES "mephisto.desktop"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/applications")
  install(FILES "mephisto.png"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/icons/hicolor/256x256/apps")
endif()