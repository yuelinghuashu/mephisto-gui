# Mephisto 开发辅助（日常命令）
#
# 发布构建由 GitHub Actions 自动完成：
#   git tag v1.0.0 && git push origin v1.0.0
# 会自动构建全平台并发布到 GitHub Releases，无需本机构建。

TARGET := lib/app/main.dart

.PHONY: run debug test analyze clean

run:            ## 开发运行（入口为 lib/app/main.dart）
	flutter run -t $(TARGET)

debug:          ## Linux 桌面调试
	flutter run -d linux -t $(TARGET)

test:           ## 运行全量测试
	flutter test

analyze:        ## 静态分析
	flutter analyze

clean:          ## 清理构建产物
	flutter clean
