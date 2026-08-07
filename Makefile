# Mephisto 开发辅助（日常命令）
#
# 发布构建由 GitHub Actions 自动完成：
#   git tag v1.0.1 && git push origin v1.0.1
# 会自动构建全平台并发布到 GitHub Releases，无需本机构建。

TARGET := lib/app/main.dart

.PHONY: run debug test analyze validate-workflows validate-build-config clean

run:            ## 开发运行（入口为 lib/app/main.dart）
	flutter run -t $(TARGET)

debug:          ## Linux 桌面调试
	flutter run -d linux -t $(TARGET)

test:           ## 运行全量测试
	flutter test

analyze:        ## 静态分析
	flutter analyze

validate-build-config: ## 构建配置静态断言（Android/iOS/打包脚本）
	python3 tool/validate_build_config.py

validate-workflows:    ## 工作流语法检查（需安装 actionlint：brew install actionlint）
	actionlint .github/workflows/*.yml

clean:          ## 清理构建产物
	flutter clean
