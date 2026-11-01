# 个人集成开发分支

基于 [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils) 的个人开发 fork，保留上游代码、许可证与归属说明。本仓库发布的是开发源码，不代表上游官方发行版。

## 新增功能

- 显示器：已有 HiDPI 模式、分辨率与刷新率切换、主屏设置、RGB ICC 颜色配置切换，以及显示配置保存和恢复。
- 显示变更：先临时预览，确认后持久保存；超时撤回，并处理显示器断开和颜色配置恢复。
- 截图：F1 框选后直接原位标注，保留暗色冻结背景，显示紧凑工具栏；边线和八个控制点支持扩大、缩小范围，标注保持屏幕位置，支持撤销／重做。
- 截图性能：复用选区窗口与原生背景层，取消空窗口列表的同步提交，普通标注不主动运行 OCR；选择文字或文字马赛克按需识别。

显示器功能仅提供系统／驱动已有且通过检查的模式，不包含虚拟屏或镜像功能。截图性能的体感改善仍需要持续验证，不宣称零延迟。

## 构建与测试

要求 macOS 14+、Apple Silicon 和 Xcode Command Line Tools。沿用上游开发构建流程：

```sh
./build.sh --dev
./build/VorssaintDeveloper --selftest
./build.sh --test-suite=display-configuration --test-suite=settings --test-suite=screenshots
```

本机最近一次截图测试通过 1,607 项检查，优化构建和 selftest 通过。显示配置与设置套件此前通过 721 项检查。实际验证包括外屏 HiDPI、模式切换、ICC 切换、主屏与配置恢复，以及原位标注、边框调整、文字输入、按需 OCR 和取消操作。

详细实现、实际验证和未测边界见：

- [显示配置模块](docs/DISPLAY-CONFIGURATION.md)
- [原位截图编辑器](docs/IN-PLACE-SCREENSHOT-EDITOR.md)

上游的 [GPL 许可证](LICENSE)、[商标说明](TRADEMARKS.md) 和 [开发贡献说明](CONTRIBUTING.md) 继续适用。本 fork 的源码与本机安装包签名是分开的；构建签名、系统权限和应用安装应依照本机开发流程处理。
