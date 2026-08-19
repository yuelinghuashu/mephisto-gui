# Mephisto 开发辅助（日常命令）
#
# 发布构建由 GitHub Actions 手动触发（Release workflow，需输入版本号如 v1.4.1）：
#   推送 main → Actions 页 → Release → Run workflow → 输入版本号
# 会自动构建全平台（Linux .deb / Android .apk / Windows .exe / macOS .dmg / iOS .ipa）
# 并发布到 GitHub Releases，无需本机构建。

TARGET := lib/main.dart

.PHONY: run debug test analyze format format-check coverage validate-workflows validate-build-config validate-l10n clean

run:            ## 开发运行（入口为 lib/main.dart，转发至 lib/app/main.dart）
	flutter run -t $(TARGET)

debug:          ## Linux 桌面调试
	flutter run -d linux -t $(TARGET)

test:           ## 运行全量测试
	flutter test

analyze:        ## 静态分析
	flutter analyze

format:         ## 一键格式化全部 Dart 代码（lib + test + tool）
	dart format lib test tool

format-check:   ## 检查格式是否合规（CI 用；不合规返回非 0）
	dart format --output=none --set-exit-if-changed lib test tool

coverage:       ## 覆盖率仪表盘（测试 + lcov 摘要，产物在 coverage/ 不入库）
	flutter test --coverage
	python3 tool/coverage_summary.py

validate-build-config: ## 构建配置静态断言（Android/iOS/打包脚本）
	python3 tool/validate_build_config.py

validate-l10n:  ## 本地化键一致性断言（zh/en .arb）
	python3 tool/validate_l10n.py

validate-workflows:    ## 工作流语法检查（需安装 actionlint：brew install actionlint）
	actionlint .github/workflows/*.yml

clean:          ## 清理构建产物
	flutter clean
