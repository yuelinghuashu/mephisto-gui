import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 统一桌面端默认窗口尺寸 + 动态居中于主屏幕。
    // macOS 窗口 frame 原点位于屏幕左下角，居中计算需以内容区尺寸为基准。
    if let screenFrame = NSScreen.main?.visibleFrame {
      let newSize = NSSize(width: 1280, height: 720)
      // 水平居中：x = (屏幕宽 - 内容宽) / 2（含左侧 Dock/菜单栏占位）
      let x = screenFrame.origin.x + (screenFrame.width - newSize.width) / 2
      // 垂直居中：y = 屏幕底部 + (可视高 - 内容高) / 2
      let y = screenFrame.origin.y + (screenFrame.height - newSize.height) / 2
      // 极端情况（屏幕小于窗口）时避免负数坐标导致窗口跑到屏幕外
      let safeX = max(screenFrame.origin.x, x)
      let safeY = max(screenFrame.origin.y, y)
      setContentSize(newSize)
      setFrameOrigin(NSPoint(x: safeX, y: safeY))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
