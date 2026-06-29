@preconcurrency import AppKit
import AudioToolbox
import CoreMedia
import CoreGraphics
import Darwin
import Foundation
import LocalVCore
@preconcurrency import ScreenCaptureKit
import WhisperKit

enum Brand {
    static let name = "LiveSub"
    static let storageName = "LiveSub"
    static let subtitleWindowTitle = "LiveSub Captions"
}

enum SubtitleParagraphMode: Int, CaseIterable {
    case fast
    case balanced
    case context

    var title: String {
        switch self {
        case .fast: return "快"
        case .balanced: return "稳"
        case .context: return "长"
        }
    }

    var description: String {
        switch self {
        case .fast: return "fast"
        case .balanced: return "balanced"
        case .context: return "context"
        }
    }

    var configuration: AudioSegmenterConfiguration {
        switch self {
        case .fast:
            return AudioSegmenterConfiguration(
                partialWindowSeconds: 2.8,
                partialIntervalSeconds: 0.55,
                maxSegmentSeconds: 10
            )
        case .balanced:
            return AudioSegmenterConfiguration(
                partialWindowSeconds: 4.2,
                partialIntervalSeconds: 0.75,
                maxSegmentSeconds: 14
            )
        case .context:
            return AudioSegmenterConfiguration(
                partialWindowSeconds: 5.8,
                partialIntervalSeconds: 1.05,
                maxSegmentSeconds: 18
            )
        }
    }

    var minimumPartialInferenceDuration: TimeInterval {
        switch self {
        case .fast: return 1.6
        case .balanced: return 2.4
        case .context: return 3.2
        }
    }
}

enum TranslationRuntimeMode: Int, CaseIterable {
    case cloudAST
    case local

    var title: String {
        switch self {
        case .cloudAST: return "云端 AST"
        case .local: return "本地"
        }
    }

    var description: String {
        switch self {
        case .cloudAST: return "cloud ast"
        case .local: return "local"
        }
    }

    var transcriptMode: LocalVMode {
        switch self {
        case .cloudAST: return .cloud
        case .local: return .live
        }
    }

    var models: ModelSelection {
        switch self {
        case .cloudAST:
            return ModelSelection(
                asrModel: "Volcengine Doubao AST 2.0",
                translationModel: "Volcengine Doubao AST s2t en->zh"
            )
        case .local:
            return ModelSelection.liveDefault
        }
    }
}

enum SubtitleContentMode: Int, CaseIterable {
    case bilingual
    case translationOnly
    case sourceOnly

    var title: String {
        switch self {
        case .bilingual: return "中英"
        case .translationOnly: return "仅中文"
        case .sourceOnly: return "仅英文"
        }
    }
}

enum SubtitleThemePreset: Int, CaseIterable {
    case dark
    case light
    case glass
    case highContrast

    var title: String {
        switch self {
        case .dark: return "暗色"
        case .light: return "浅色"
        case .glass: return "玻璃"
        case .highContrast: return "高对比"
        }
    }

    var colors: (
        primary: NSColor,
        secondary: NSColor,
        background: NSColor,
        textBacking: NSColor,
        backgroundOpacity: CGFloat,
        textBackingOpacity: CGFloat,
        panelOpacity: CGFloat
    ) {
        switch self {
        case .dark:
            return (.white, NSColor.white.withAlphaComponent(0.74), .black, .black, 0.74, 0.0, 0.96)
        case .light:
            return (.black, NSColor.black.withAlphaComponent(0.62), .white, .white, 0.84, 0.0, 0.96)
        case .glass:
            return (.white, NSColor.white.withAlphaComponent(0.72), .black, .black, 0.42, 0.0, 0.90)
        case .highContrast:
            return (.white, NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.36, alpha: 1.0), .black, .black, 0.92, 0.18, 1.0)
        }
    }
}

enum SubtitleFontPreset: Int, CaseIterable {
    case small
    case medium
    case large
    case extraLarge

    var title: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "超大"
        }
    }

    var primarySize: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 29
        case .extraLarge: return 34
        }
    }
}

enum SubtitleWindowSizePreset: Int, CaseIterable {
    case compact
    case comfortable
    case wide

    var title: String {
        switch self {
        case .compact: return "低"
        case .comfortable: return "中"
        case .wide: return "高"
        }
    }

    var size: (width: CGFloat, height: CGFloat) {
        switch self {
        case .compact: return (760, 300)
        case .comfortable: return (940, 430)
        case .wide: return (1120, 560)
        }
    }
}

@MainActor
final class CaptionScrollView: NSScrollView {
    var hoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        hoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverChanged?(false)
    }
}

@MainActor
final class CaptionDragHandleView: NSView {
    var canDragWindow = true

    override func mouseDown(with event: NSEvent) {
        guard canDragWindow else {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }
}

@MainActor
final class CaptionPanelContentView: NSView {
    var hoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        hoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverChanged?(false)
    }
}

@MainActor
final class CompactDotView: NSView {
    var onLeftClick: (() -> Void)?
    var onDragEnded: ((NSPoint) -> Void)?
    var menuProvider: (() -> NSMenu)?

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let ovalRect = bounds.insetBy(dx: 5, dy: 5)
        let ovalPath = NSBezierPath(ovalIn: ovalRect)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 9
        shadow.set()

        NSGradient(colors: [
            NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.16, alpha: 0.96),
            NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.95, alpha: 0.96)
        ])?.draw(in: ovalPath, angle: -35)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.20).setStroke()
        ovalPath.lineWidth = 1
        ovalPath.stroke()

        let glint = NSBezierPath(ovalIn: NSRect(
            x: ovalRect.minX + ovalRect.width * 0.24,
            y: ovalRect.maxY - ovalRect.height * 0.34,
            width: ovalRect.width * 0.24,
            height: ovalRect.height * 0.10
        ))
        NSColor.white.withAlphaComponent(0.30).setFill()
        glint.fill()

        let mark = "S" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.96),
            .paragraphStyle: paragraph
        ]
        let markSize = mark.size(withAttributes: attributes)
        let markRect = NSRect(
            x: bounds.midX - markSize.width / 2,
            y: bounds.midY - markSize.height / 2 - 1,
            width: markSize.width,
            height: markSize.height
        )
        mark.draw(in: markRect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        guard let eventWindow = window else {
            onLeftClick?()
            return
        }

        let dragStartScreenPoint = NSEvent.mouseLocation
        let dragStartWindowOrigin = eventWindow.frame.origin
        var didDrag = false

        while NSEvent.pressedMouseButtons & 1 == 1 {
            let currentPoint = NSEvent.mouseLocation
            let deltaX = currentPoint.x - dragStartScreenPoint.x
            let deltaY = currentPoint.y - dragStartScreenPoint.y
            if abs(deltaX) > 2 || abs(deltaY) > 2 {
                didDrag = true
                eventWindow.setFrameOrigin(NSPoint(
                    x: dragStartWindowOrigin.x + deltaX,
                    y: dragStartWindowOrigin.y + deltaY
                ))
            }

            if !RunLoop.current.run(mode: .eventTracking, before: Date(timeIntervalSinceNow: 0.01)) {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        if didDrag {
            onDragEnded?(eventWindow.frame.origin)
        } else {
            onLeftClick?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let eventWindow = window else { return }
        let dragStartScreenPoint = screenPoint(for: event, in: eventWindow)
        let dragStartWindowOrigin = eventWindow.frame.origin

        while NSEvent.pressedMouseButtons & 1 == 1 {
            let currentPoint = NSEvent.mouseLocation
            let deltaX = currentPoint.x - dragStartScreenPoint.x
            let deltaY = currentPoint.y - dragStartScreenPoint.y
            if abs(deltaX) > 2 || abs(deltaY) > 2 {
                eventWindow.setFrameOrigin(NSPoint(
                    x: dragStartWindowOrigin.x + deltaX,
                    y: dragStartWindowOrigin.y + deltaY
                ))
            }

            if !RunLoop.current.run(mode: .eventTracking, before: Date(timeIntervalSinceNow: 0.01)) {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        onDragEnded?(eventWindow.frame.origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard let eventWindow = window else {
            onLeftClick?()
            return
        }

        let currentPoint = NSEvent.mouseLocation
        let eventPoint = screenPoint(for: event, in: eventWindow)
        if abs(currentPoint.x - eventPoint.x) <= 2 && abs(currentPoint.y - eventPoint.y) <= 2 {
            onLeftClick?()
        } else {
            onDragEnded?(eventWindow.frame.origin)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let circleRect = bounds.insetBy(dx: 5, dy: 5)
        let center = NSPoint(x: circleRect.midX, y: circleRect.midY)
        let radius = min(circleRect.width, circleRect.height) / 2
        let dx = point.x - center.x
        let dy = point.y - center.y
        return (dx * dx + dy * dy) <= radius * radius ? self : nil
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window else { return .zero }
        return screenPoint(for: event, in: window)
    }

    private func screenPoint(for event: NSEvent, in window: NSWindow) -> NSPoint {
        let locationInWindow = event.locationInWindow
        let rect = NSRect(origin: locationInWindow, size: .zero)
        return window.convertToScreen(rect).origin
    }
}

@main
struct LocalVAppShell {
    @MainActor private static let delegate = AppDelegate()

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.mainMenu = AppMenu.build()
        app.finishLaunching()
        delegate.show()
        app.run()
    }
}

enum AppMenu {
    @MainActor
    static func build() -> NSMenu {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: Brand.name)
        appMenu.addItem(
            NSMenuItem(
                title: "Quit \(Brand.name)",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        return mainMenu
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private struct CaptionBlock {
        var translation: String
        var source: String
    }

    private var window: NSWindow?
    private var subtitlePanel: NSPanel?
    private var compactDotPanel: NSPanel?
    private var diagnosticsWindow: NSWindow?
    private var sourceLabel = NSTextField(labelWithString: "Google Chrome")
    private var captureLabel = NSTextField(labelWithString: "未启动")
    private var vadLabel = NSTextField(labelWithString: "VAD: idle")
    private var bufferLabel = NSTextField(labelWithString: "Buffers: 0")
    private var rmsLabel = NSTextField(labelWithString: "RMS: 0.00000")
    private var windowLabel = NSTextField(labelWithString: "Windows: 0")
    private var subtitleLabel = NSTextField(wrappingLabelWithString: "Open Chrome audio, then press Start.")
    private var subtitleSecondaryLabel = NSTextField(wrappingLabelWithString: "")
    private var subtitleMetaLabel = NSTextField(labelWithString: "\(Brand.name) ready")
    private var modeLabel = NSTextField(labelWithString: "云端 AST / 稳")
    private var resourceLabel = NSTextField(labelWithString: "测量中...")
    private var lastEventLabel = NSTextField(labelWithString: "就绪")
    private var logView: NSTextView?
    private var startButton: NSButton?
    private var stopButton: NSButton?
    private var collapseButton: NSButton?
    private var cloudTestButton: NSButton?
    private var primaryFontSizeSlider: NSSlider?
    private var panelOpacitySlider: NSSlider?
    private var backgroundOpacitySlider: NSSlider?
    private var panelWidthSlider: NSSlider?
    private var textBackingOpacitySlider: NSSlider?
    private var primaryTextColorWell: NSColorWell?
    private var secondaryTextColorWell: NSColorWell?
    private var backgroundColorWell: NSColorWell?
    private var textBackingColorWell: NSColorWell?
    private var paragraphModeControl: NSSegmentedControl?
    private var runtimeModeControl: NSSegmentedControl?
    private var contentModeControl: NSSegmentedControl?
    private var themePresetControl: NSSegmentedControl?
    private var fontPresetControl: NSSegmentedControl?
    private var windowSizePresetControl: NSSegmentedControl?
    private var settingsTabControl: NSSegmentedControl?
    private var settingsPageContainer: NSView?
    private var settingsPages: [NSView] = []
    private var subtitleAlwaysOnTopButton: NSButton?
    private var subtitleLockPositionButton: NSButton?
    private var cloudCredentialLabel = NSTextField(labelWithString: "Cloud: not configured")
    private var subtitlePanelContentView: CaptionPanelContentView?
    private var subtitleTranscriptView: NSTextView?
    private var subtitleOverlayLabel: NSTextField?
    private var subtitleScrollView: NSScrollView?
    private var subtitleJumpToLatestButton: NSButton?
    private var subtitleDragHandleView: CaptionDragHandleView?
    private var subtitleDragGripView: NSView?
    private var subtitleControlRow: NSStackView?
    private var subtitleTextOnlyButton: NSButton?
    private var subtitleCloseButton: NSButton?
    private var subtitleScrollObserver: NSObjectProtocol?

    private var activeStream: SCStream?
    private var activeProbe: AudioProbe?
    private var activeCloudClient: VolcengineASTClient?
    private var activeRuntimeMode: TranslationRuntimeMode?
    private var cloudTestTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    private var speechWindowCount = 0
    private let asrEngine = WhisperASREngine()
    private let translator = OllamaTranslator()
    private var activeInferenceTask: Task<Void, Never>?
    private var pendingInferenceWindow: SpeechWindow?
    private var transcriptPersistence: TranscriptPersistence?
    private var persistedSubtitleCount = 0
    private var hasRenderedSubtitle = false
    private var resourceMonitorTask: Task<Void, Never>?
    private var primarySubtitleFontSize: CGFloat = 24
    private var secondarySubtitleFontSize: CGFloat = 15
    private var subtitlePanelOpacity: CGFloat = 0.94
    private var subtitleBackgroundOpacity: CGFloat = 0.72
    private var subtitlePanelWidth: CGFloat = 920
    private var subtitlePanelHeight: CGFloat = 430
    private var subtitleTextBackingOpacity: CGFloat = 0.18
    private var primarySubtitleTextColor = NSColor.white
    private var secondarySubtitleTextColor = NSColor.white.withAlphaComponent(0.78)
    private var subtitleBackgroundColor = NSColor.black
    private var subtitleTextBackingColor = NSColor.black
    private var paragraphMode: SubtitleParagraphMode = .balanced
    private var runtimeMode: TranslationRuntimeMode = .cloudAST
    private var subtitleContentMode: SubtitleContentMode = .bilingual
    private var subtitleThemePreset: SubtitleThemePreset = .dark
    private var subtitleFontPreset: SubtitleFontPreset = .medium
    private var subtitleWindowSizePreset: SubtitleWindowSizePreset = .comfortable
    private var subtitleAlwaysOnTop = true
    private var subtitlePositionLocked = false
    private var subtitleTextOnlyMode = true
    private var cloudCurrentSourceText = ""
    private var cloudCurrentTranslationText = ""
    private var cloudEstimatedCostCNY: Double = 0
    private var captionBlocks: [CaptionBlock] = []
    private var captionCurrentBlock = CaptionBlock(translation: "", source: "")
    private var diagnosticLines: [String] = []
    private var subtitleHoverPaused = false
    private var subtitleHasUnreadContent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSubtitlePreferences()
        show()
        startResourceMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        resourceMonitorTask?.cancel()
        cloudTestTask?.cancel()
    }

    func show() {
        buildMainWindowIfNeeded()
        buildSubtitlePanelIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func savedWindowFrame(forKey key: String) -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: key) else { return nil }
        let frame = NSRectFromString(frameString)
        return frame.isEmpty ? nil : frame
    }

    private func saveWindowFrame(_ frame: NSRect, forKey key: String) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: key)
    }

    private func constrainedWindowFrame(_ frame: NSRect, minimumSize: NSSize) -> NSRect {
        var adjusted = frame
        adjusted.size.width = max(adjusted.width, minimumSize.width)
        adjusted.size.height = max(adjusted.height, minimumSize.height)

        guard let screenFrame = NSScreen.screens.first(where: { $0.visibleFrame.intersects(adjusted) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame else {
            return adjusted
        }

        adjusted.size.width = min(adjusted.width, screenFrame.width - 8)
        adjusted.size.height = min(adjusted.height, screenFrame.height - 8)
        adjusted.origin.x = min(max(adjusted.origin.x, screenFrame.minX + 4), screenFrame.maxX - adjusted.width - 4)
        adjusted.origin.y = min(max(adjusted.origin.y, screenFrame.minY + 4), screenFrame.maxY - adjusted.height - 4)
        return adjusted
    }

    func windowDidMove(_ notification: Notification) {
        saveFrameForManagedWindow(notification.object)
    }

    func windowDidResize(_ notification: Notification) {
        saveFrameForManagedWindow(notification.object)
    }

    private func saveFrameForManagedWindow(_ object: Any?) {
        guard let movedWindow = object as? NSWindow else { return }
        if movedWindow === window {
            saveWindowFrame(movedWindow.frame, forKey: "mainWindow.frame")
        } else if movedWindow === subtitlePanel {
            subtitlePanelWidth = movedWindow.frame.width
            subtitlePanelHeight = movedWindow.frame.height
            saveWindowFrame(movedWindow.frame, forKey: "subtitlePanel.frame")
            saveSubtitlePreferences()
        }
    }

    private func buildMainWindowIfNeeded() {
        guard window == nil else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 780, height: 500)
        window.title = "\(Brand.name) Settings"
        window.delegate = self
        if let frame = savedWindowFrame(forKey: "mainWindow.frame") {
            window.setFrame(constrainedWindowFrame(frame, minimumSize: window.minSize), display: false)
        } else {
            window.center()
        }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .width
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false

        let startButton = NSButton(
            title: "开始 Chrome 字幕",
            target: self,
            action: #selector(startChromeCapture)
        )
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.keyEquivalent = "\r"

        let stopButton = NSButton(
            title: "停止",
            target: self,
            action: #selector(stopCapture)
        )
        stopButton.bezelStyle = .rounded
        stopButton.controlSize = .large
        stopButton.isEnabled = false
        self.startButton = startButton
        self.stopButton = stopButton

        let collapseButton = NSButton(
            title: "收起",
            target: self,
            action: #selector(collapseMainWindowToDot)
        )
        collapseButton.bezelStyle = .rounded
        collapseButton.controlSize = .large
        self.collapseButton = collapseButton

        let title = NSTextField(labelWithString: Brand.name)
        title.font = NSFont.systemFont(ofSize: 30, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Chrome 实时字幕配置中心")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = NSFont.systemFont(ofSize: 13)

        let headerText = NSStackView()
        headerText.orientation = .vertical
        headerText.spacing = 3
        headerText.addArrangedSubview(title)
        headerText.addArrangedSubview(subtitle)

        let headerButtons = NSStackView()
        headerButtons.orientation = .horizontal
        headerButtons.spacing = 8
        headerButtons.addArrangedSubview(collapseButton)
        headerButtons.addArrangedSubview(stopButton)
        headerButtons.addArrangedSubview(startButton)

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 18
        header.addArrangedSubview(headerText)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(headerButtons)

        for label in [sourceLabel, captureLabel, modeLabel, resourceLabel, lastEventLabel] {
            label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
        }

        let statusStrip = makeStatusStrip()

        let paragraphControl = NSSegmentedControl(
            labels: SubtitleParagraphMode.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(paragraphModeChanged(_:))
        )
        paragraphControl.selectedSegment = paragraphMode.rawValue
        paragraphModeControl = paragraphControl

        let contentModeControl = NSSegmentedControl(
            labels: SubtitleContentMode.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(contentModeChanged(_:))
        )
        contentModeControl.selectedSegment = subtitleContentMode.rawValue
        self.contentModeControl = contentModeControl

        let themeControl = NSSegmentedControl(
            labels: SubtitleThemePreset.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(themePresetChanged(_:))
        )
        themeControl.selectedSegment = subtitleThemePreset.rawValue
        self.themePresetControl = themeControl

        let fontControl = NSSegmentedControl(
            labels: SubtitleFontPreset.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(fontPresetChanged(_:))
        )
        fontControl.selectedSegment = subtitleFontPreset.rawValue
        self.fontPresetControl = fontControl

        let windowSizeControl = NSSegmentedControl(
            labels: SubtitleWindowSizePreset.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(windowSizePresetChanged(_:))
        )
        windowSizeControl.selectedSegment = subtitleWindowSizePreset.rawValue
        self.windowSizePresetControl = windowSizeControl

        let alwaysOnTopButton = NSButton(
            checkboxWithTitle: "置顶",
            target: self,
            action: #selector(subtitleWindowBehaviorChanged(_:))
        )
        alwaysOnTopButton.state = subtitleAlwaysOnTop ? .on : .off
        self.subtitleAlwaysOnTopButton = alwaysOnTopButton

        let lockPositionButton = NSButton(
            checkboxWithTitle: "锁定位置",
            target: self,
            action: #selector(subtitleWindowBehaviorChanged(_:))
        )
        lockPositionButton.state = subtitlePositionLocked ? .on : .off
        self.subtitleLockPositionButton = lockPositionButton

        let showPanelButton = NSButton(
            title: "显示字幕浮窗",
            target: self,
            action: #selector(showSubtitlePanel)
        )
        showPanelButton.bezelStyle = .rounded

        let hidePanelButton = NSButton(
            title: "关闭字幕浮窗",
            target: self,
            action: #selector(hideSubtitlePanel)
        )
        hidePanelButton.bezelStyle = .rounded

        let clearCaptionsButton = NSButton(
            title: "清空浮窗",
            target: self,
            action: #selector(clearCaptionWindow)
        )
        clearCaptionsButton.bezelStyle = .rounded

        let advancedAppearanceButton = NSButton(
            title: "高级外观",
            target: self,
            action: #selector(showAppearanceSettings)
        )
        advancedAppearanceButton.bezelStyle = .rounded

        let subtitleRows = NSStackView()
        subtitleRows.orientation = .vertical
        subtitleRows.alignment = .width
        subtitleRows.spacing = 12

        let subtitleRow1 = NSStackView()
        subtitleRow1.orientation = .horizontal
        subtitleRow1.spacing = 12
        subtitleRow1.addArrangedSubview(settingControl(title: "内容", control: contentModeControl, width: 178))
        subtitleRow1.addArrangedSubview(settingControl(title: "主题", control: themeControl, width: 260))
        subtitleRow1.addArrangedSubview(settingControl(title: "段落", control: paragraphControl, width: 132))
        subtitleRow1.addArrangedSubview(NSView())

        let subtitleRow2 = NSStackView()
        subtitleRow2.orientation = .horizontal
        subtitleRow2.spacing = 12
        subtitleRow2.addArrangedSubview(settingControl(title: "字号", control: fontControl, width: 190))
        subtitleRow2.addArrangedSubview(settingControl(title: "窗口大小", control: windowSizeControl, width: 144))
        subtitleRow2.addArrangedSubview(alwaysOnTopButton)
        subtitleRow2.addArrangedSubview(lockPositionButton)
        subtitleRow2.addArrangedSubview(showPanelButton)
        subtitleRow2.addArrangedSubview(hidePanelButton)
        subtitleRow2.addArrangedSubview(clearCaptionsButton)
        subtitleRow2.addArrangedSubview(advancedAppearanceButton)
        subtitleRow2.addArrangedSubview(NSView())

        subtitleRows.addArrangedSubview(subtitleRow1)
        subtitleRows.addArrangedSubview(subtitleRow2)
        let subtitleSection = makeSection(
            title: "字幕外观",
            detail: "这里只管字幕浮窗的阅读体验；工作时可以收起主窗口，只留下浮窗和圆点。",
            content: subtitleRows
        )

        let runtimeControl = NSSegmentedControl(
            labels: TranslationRuntimeMode.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(runtimeModeChanged(_:))
        )
        runtimeControl.selectedSegment = runtimeMode.rawValue
        runtimeModeControl = runtimeControl

        let cloudSettingsButton = NSButton(
            title: "配置豆包",
            target: self,
            action: #selector(configureCloudCredentials)
        )
        cloudSettingsButton.bezelStyle = .rounded

        let cloudTestButton = NSButton(
            title: "测试连接",
            target: self,
            action: #selector(testCloudConnection)
        )
        cloudTestButton.bezelStyle = .rounded
        self.cloudTestButton = cloudTestButton

        cloudCredentialLabel.textColor = .secondaryLabelColor
        cloudCredentialLabel.font = NSFont.systemFont(ofSize: 12)

        let engineRows = NSStackView()
        engineRows.orientation = .vertical
        engineRows.alignment = .width
        engineRows.spacing = 12
        let engineRow = NSStackView()
        engineRow.orientation = .horizontal
        engineRow.spacing = 12
        engineRow.addArrangedSubview(settingControl(title: "引擎", control: runtimeControl, width: 168))
        engineRow.addArrangedSubview(cloudSettingsButton)
        engineRow.addArrangedSubview(cloudTestButton)
        engineRow.addArrangedSubview(cloudCredentialLabel)
        engineRow.addArrangedSubview(NSView())
        engineRows.addArrangedSubview(engineRow)
        let engineSection = makeSection(
            title: "引擎与账号",
            detail: "默认云端低占用；本地模式适合完全离线。改动会在下一次开始字幕时完整生效。",
            content: engineRows
        )

        let privacyButton = NSButton(
            title: "申请系统音频权限",
            target: self,
            action: #selector(requestCapturePermission)
        )
        privacyButton.bezelStyle = .rounded
        let diagnosticsButton = NSButton(
            title: "高级诊断",
            target: self,
            action: #selector(showDiagnostics)
        )
        diagnosticsButton.bezelStyle = .rounded
        let openSessionsButton = NSButton(
            title: "打开保存目录",
            target: self,
            action: #selector(openSessionsFolder)
        )
        openSessionsButton.bezelStyle = .rounded
        let sessionHint = NSTextField(
            wrappingLabelWithString: "字幕会自动保存到 ~/Library/Application Support/LiveSub/Sessions/"
        )
        sessionHint.textColor = .secondaryLabelColor
        sessionHint.font = NSFont.systemFont(ofSize: 12)
        let sessionRow = NSStackView()
        sessionRow.orientation = .horizontal
        sessionRow.spacing = 12
        sessionRow.addArrangedSubview(privacyButton)
        sessionRow.addArrangedSubview(openSessionsButton)
        sessionRow.addArrangedSubview(diagnosticsButton)
        sessionRow.addArrangedSubview(sessionHint)
        sessionRow.addArrangedSubview(NSView())
        let sessionSection = makeSection(
            title: "记录与诊断",
            detail: "这里处理权限、保存目录和少量高级排障；日常工作不需要常看。",
            content: sessionRow
        )

        let tabControl = NSSegmentedControl(
            labels: ["字幕外观", "引擎与账号", "记录与诊断"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(settingsTabChanged(_:))
        )
        tabControl.selectedSegment = 0
        tabControl.controlSize = .large
        settingsTabControl = tabControl

        let subtitlePage = makeSettingsPage(content: subtitleSection)
        let enginePage = makeSettingsPage(content: engineSection)
        let recordsPage = makeSettingsPage(content: sessionSection)
        settingsPages = [subtitlePage, enginePage, recordsPage]
        enginePage.isHidden = true
        recordsPage.isHidden = true

        let pageContainer = NSView()
        pageContainer.translatesAutoresizingMaskIntoConstraints = false
        for page in settingsPages {
            pageContainer.addSubview(page)
            NSLayoutConstraint.activate([
                page.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
                page.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor),
                page.topAnchor.constraint(equalTo: pageContainer.topAnchor),
                page.bottomAnchor.constraint(lessThanOrEqualTo: pageContainer.bottomAnchor)
            ])
        }
        pageContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        settingsPageContainer = pageContainer

        let tabRow = NSStackView()
        tabRow.orientation = .horizontal
        tabRow.alignment = .centerY
        tabRow.spacing = 12
        tabRow.addArrangedSubview(tabControl)
        tabRow.addArrangedSubview(NSView())

        let settingsTabs = NSStackView()
        settingsTabs.orientation = .vertical
        settingsTabs.alignment = .width
        settingsTabs.spacing = 12
        settingsTabs.addArrangedSubview(tabRow)
        settingsTabs.addArrangedSubview(pageContainer)
        tabRow.widthAnchor.constraint(equalTo: settingsTabs.widthAnchor).isActive = true
        pageContainer.widthAnchor.constraint(equalTo: settingsTabs.widthAnchor).isActive = true

        root.addArrangedSubview(header)
        root.addArrangedSubview(statusStrip)
        root.addArrangedSubview(settingsTabs)
        root.addArrangedSubview(NSView())
        statusStrip.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        settingsTabs.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let content = NSView()
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        window.contentView = content
        self.window = window

        appendLog("\(Brand.name) ready.")
        appendLog("Default source is Google Chrome app-level audio via ScreenCaptureKit.")
        appendLog("Pipeline: Cloud AST or local WhisperKit/Ollama -> subtitles + transcript files.")
        appendLog("Press Start. If macOS denies capture, click 申请权限 or allow \(Brand.name) in Screen & System Audio Recording.")
        lastEventLabel.stringValue = "就绪，点击开始 Chrome 字幕"
        lastEventLabel.toolTip = "就绪，点击开始 Chrome 字幕"
        applySubtitleStyle()
        updateParagraphModeLabel()
        updateCloudCredentialLabel()
    }

    private func buildCompactDotIfNeeded() {
        guard compactDotPanel == nil else { return }

        let size: CGFloat = 54
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "\(Brand.name) Dot"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false

        let dotView = CompactDotView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        dotView.autoresizingMask = [.width, .height]
        dotView.toolTip = "\(Brand.name)：左键打开，拖动移动，右键菜单"
        dotView.onLeftClick = { [weak self] in
            self?.expandMainWindowFromDot()
        }
        dotView.onDragEnded = { [weak self] origin in
            self?.saveCompactDotOrigin(origin)
        }
        dotView.menuProvider = { [weak self] in
            self?.makeCompactDotMenu() ?? NSMenu(title: Brand.name)
        }

        panel.contentView = dotView
        panel.setFrameOrigin(compactDotInitialOrigin(size: size))
        compactDotPanel = panel
    }

    @objc private func collapseMainWindowToDot() {
        buildCompactDotIfNeeded()
        window?.orderOut(nil)
        compactDotPanel?.orderFront(nil)
    }

    @objc private func expandMainWindowFromDot() {
        compactDotPanel?.orderOut(nil)
        buildMainWindowIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func settingsTabChanged(_ sender: NSSegmentedControl) {
        guard sender.selectedSegment >= 0 else { return }
        for (index, page) in settingsPages.enumerated() {
            page.isHidden = index != sender.selectedSegment
        }
    }

    private func makeCompactDotMenu() -> NSMenu {
        let menu = NSMenu(title: Brand.name)
        menu.autoenablesItems = false

        menu.addItem(compactDotMenuItem("打开配置中心", action: #selector(expandMainWindowFromDot)))
        menu.addItem(.separator())

        let isCapturing = activeStream != nil
        menu.addItem(compactDotMenuItem("开始 Chrome 字幕", action: #selector(startChromeCapture), enabled: !isCapturing))
        menu.addItem(compactDotMenuItem("停止字幕", action: #selector(stopCapture), enabled: isCapturing))
        menu.addItem(compactDotMenuItem("显示字幕浮窗", action: #selector(showSubtitlePanel)))
        menu.addItem(compactDotMenuItem("关闭字幕浮窗", action: #selector(hideSubtitlePanel)))
        menu.addItem(compactDotMenuItem(subtitleTextOnlyMode ? "字幕恢复面板" : "字幕纯字模式", action: #selector(toggleSubtitleTextOnlyMode)))

        let alwaysOnTopItem = compactDotMenuItem("字幕浮窗置顶", action: #selector(toggleSubtitleAlwaysOnTopFromDotMenu))
        alwaysOnTopItem.state = subtitleAlwaysOnTop ? .on : .off
        menu.addItem(alwaysOnTopItem)

        menu.addItem(compactDotMenuItem("清空字幕", action: #selector(clearCaptionWindow)))
        menu.addItem(.separator())
        menu.addItem(compactDotMenuItem("配置豆包", action: #selector(configureCloudCredentials)))
        menu.addItem(compactDotMenuItem("测试连接", action: #selector(testCloudConnection), enabled: cloudTestTask == nil && activeStream == nil))
        menu.addItem(compactDotMenuItem("高级外观", action: #selector(showAppearanceSettings)))
        menu.addItem(compactDotMenuItem("高级诊断", action: #selector(showDiagnostics)))
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 \(Brand.name)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        quitItem.isEnabled = true
        menu.addItem(quitItem)
        return menu
    }

    private func compactDotMenuItem(_ title: String, action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        return item
    }

    @objc private func toggleSubtitleAlwaysOnTopFromDotMenu() {
        subtitleAlwaysOnTop.toggle()
        subtitleAlwaysOnTopButton?.state = subtitleAlwaysOnTop ? .on : .off
        applySubtitleWindowBehavior()
        saveSubtitlePreferences()
    }

    private func compactDotInitialOrigin(size: CGFloat) -> NSPoint {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "compactDot.originX") != nil,
           defaults.object(forKey: "compactDot.originY") != nil {
            return constrainedCompactDotOrigin(
                NSPoint(
                    x: defaults.double(forKey: "compactDot.originX"),
                    y: defaults.double(forKey: "compactDot.originY")
                ),
                size: size
            )
        }

        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return NSPoint(x: 24, y: 24)
        }
        return NSPoint(
            x: screenFrame.maxX - size - 24,
            y: screenFrame.maxY - size - 24
        )
    }

    private func constrainedCompactDotOrigin(_ origin: NSPoint, size: CGFloat) -> NSPoint {
        guard let screenFrame = NSScreen.screens.first(where: { $0.visibleFrame.insetBy(dx: -size, dy: -size).contains(origin) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame else {
            return origin
        }

        return NSPoint(
            x: min(max(origin.x, screenFrame.minX + 4), screenFrame.maxX - size - 4),
            y: min(max(origin.y, screenFrame.minY + 4), screenFrame.maxY - size - 4)
        )
    }

    private func saveCompactDotOrigin(_ origin: NSPoint) {
        let size = compactDotPanel?.frame.width ?? 54
        let constrainedOrigin = constrainedCompactDotOrigin(origin, size: size)
        compactDotPanel?.setFrameOrigin(constrainedOrigin)
        let defaults = UserDefaults.standard
        defaults.set(Double(constrainedOrigin.x), forKey: "compactDot.originX")
        defaults.set(Double(constrainedOrigin.y), forKey: "compactDot.originY")
    }

    private func makeSlider(min: Double, max: Double, value: Double, action: Selector) -> NSSlider {
        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
        return slider
    }

    private func makeColorWell(color: NSColor, action: Selector) -> NSColorWell {
        let well = NSColorWell(frame: NSRect(x: 0, y: 0, width: 44, height: 28))
        well.color = color
        well.target = self
        well.action = action
        return well
    }

    private func makeStatusStrip() -> NSBox {
        let box = NSBox()
        box.title = ""
        box.boxType = .custom
        box.cornerRadius = 8
        box.fillColor = NSColor.controlBackgroundColor
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.28)
        box.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(statusItem(title: "状态", value: captureLabel))
        row.addArrangedSubview(statusItem(title: "来源", value: sourceLabel))
        row.addArrangedSubview(statusItem(title: "引擎", value: modeLabel))
        row.addArrangedSubview(statusItem(title: "占用", value: resourceLabel))
        row.addArrangedSubview(statusItem(title: "最近", value: lastEventLabel))

        box.contentView?.addSubview(row)
        if let contentView = box.contentView {
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                row.topAnchor.constraint(equalTo: contentView.topAnchor),
                row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        return box
    }

    private func statusItem(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .left
        value.lineBreakMode = .byTruncatingTail
        value.alignment = .left
        value.toolTip = value.stringValue

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(value)
        stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        return stack
    }

    private func makeSettingsPage(content: NSView) -> NSView {
        let page = NSView()
        page.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            content.topAnchor.constraint(equalTo: page.topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor)
        ])
        return page
    }

    private func makeSection(title: String, detail: String?, content: NSView) -> NSBox {
        let box = NSBox()
        box.title = ""
        box.boxType = .primary
        box.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .left
        stack.addArrangedSubview(titleLabel)

        if let detail {
            let detailLabel = NSTextField(wrappingLabelWithString: detail)
            detailLabel.font = NSFont.systemFont(ofSize: 12)
            detailLabel.textColor = .secondaryLabelColor
            detailLabel.alignment = .left
            stack.addArrangedSubview(detailLabel)
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        stack.addArrangedSubview(content)
        content.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        box.contentView?.addSubview(stack)
        if let contentView = box.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stack.topAnchor.constraint(equalTo: contentView.topAnchor),
                stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }

        return box
    }

    private func settingControl(title: String, control: NSView, width: CGFloat) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .left

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(control)
        control.widthAnchor.constraint(equalToConstant: width).isActive = true
        return stack
    }

    private func buildSubtitlePanelIfNeeded() {
        guard subtitlePanel == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: subtitlePanelWidth, height: preferredSubtitlePanelHeight()),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = Brand.subtitleWindowTitle
        panel.level = subtitleAlwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.alphaValue = subtitlePanelOpacity
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = !subtitleTextOnlyMode
        panel.isMovableByWindowBackground = !subtitlePositionLocked
        panel.delegate = self

        let scrollView = CaptionScrollView()
        scrollView.identifier = NSUserInterfaceItemIdentifier("captionScrollView")
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.hoverChanged = { [weak self] hovering in
            Task { @MainActor in
                self?.subtitleHoverPaused = hovering
            }
        }
        subtitleScrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.subtitleScrollDidMove()
            }
        }

        let textView = NSTextView()
        textView.identifier = NSUserInterfaceItemIdentifier("captionTranscript")
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 18, height: 22)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: subtitlePanelWidth - 48, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        let content = CaptionPanelContentView()
        content.wantsLayer = true
        content.layer?.cornerRadius = 18
        content.layer?.masksToBounds = true
        content.layer?.backgroundColor = subtitleBackgroundColor.withAlphaComponent(subtitleBackgroundOpacity).cgColor
        content.hoverChanged = { [weak self] hovering in
            Task { @MainActor in
                self?.subtitleHoverPaused = hovering
                self?.updateSubtitleControlVisibility()
            }
        }
        content.addSubview(scrollView)

        let overlayLabel = NSTextField(wrappingLabelWithString: "")
        overlayLabel.identifier = NSUserInterfaceItemIdentifier("captionTextOnlyOverlay")
        overlayLabel.alignment = .center
        overlayLabel.maximumNumberOfLines = 14
        overlayLabel.lineBreakMode = .byWordWrapping
        overlayLabel.drawsBackground = false
        overlayLabel.backgroundColor = .clear
        overlayLabel.isBordered = false
        overlayLabel.isSelectable = false
        overlayLabel.isHidden = true
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(overlayLabel)

        let dragHandle = CaptionDragHandleView()
        dragHandle.canDragWindow = !subtitlePositionLocked
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.wantsLayer = true
        dragHandle.layer?.backgroundColor = NSColor.clear.cgColor
        content.addSubview(dragHandle)

        let handlePill = NSView()
        handlePill.translatesAutoresizingMaskIntoConstraints = false
        handlePill.wantsLayer = true
        handlePill.layer?.cornerRadius = 2
        handlePill.layer?.backgroundColor = primarySubtitleTextColor.withAlphaComponent(0.36).cgColor
        dragHandle.addSubview(handlePill)

        let controlRow = NSStackView()
        controlRow.orientation = .horizontal
        controlRow.alignment = .centerY
        controlRow.spacing = 6
        controlRow.translatesAutoresizingMaskIntoConstraints = false

        let textOnlyButton = subtitleChromeButton(title: subtitleTextOnlyMode ? "面板" : "纯字", action: #selector(toggleSubtitleTextOnlyMode))
        let closeButton = subtitleChromeButton(title: "×", action: #selector(hideSubtitlePanel))
        controlRow.addArrangedSubview(textOnlyButton)
        controlRow.addArrangedSubview(closeButton)
        content.addSubview(controlRow)

        let jumpButton = NSButton(
            title: "回到最新",
            target: self,
            action: #selector(jumpSubtitleToLatest)
        )
        jumpButton.bezelStyle = .rounded
        jumpButton.controlSize = .small
        jumpButton.isHidden = true
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(jumpButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            overlayLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            overlayLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            overlayLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            overlayLabel.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 18),
            overlayLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -18),
            dragHandle.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            dragHandle.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            dragHandle.topAnchor.constraint(equalTo: content.topAnchor),
            dragHandle.heightAnchor.constraint(equalToConstant: 28),
            handlePill.centerXAnchor.constraint(equalTo: dragHandle.centerXAnchor),
            handlePill.centerYAnchor.constraint(equalTo: dragHandle.centerYAnchor),
            handlePill.widthAnchor.constraint(equalToConstant: 72),
            handlePill.heightAnchor.constraint(equalToConstant: 4),
            controlRow.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            controlRow.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
            jumpButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            jumpButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        panel.contentView = content
        if let frame = savedWindowFrame(forKey: "subtitlePanel.frame") {
            let constrainedFrame = constrainedWindowFrame(
                frame,
                minimumSize: NSSize(width: 420, height: 160)
            )
            subtitlePanelWidth = constrainedFrame.width
            subtitlePanelHeight = constrainedFrame.height
            panel.setFrame(constrainedFrame, display: false)
        } else if let screenFrame = NSScreen.main?.visibleFrame {
            let defaultWidth = min(max(720, screenFrame.width * 0.68), 1120)
            subtitlePanelWidth = defaultWidth
            var defaultFrame = panel.frame
            defaultFrame.size.width = defaultWidth
            defaultFrame.size.height = preferredSubtitlePanelHeight()
            defaultFrame.origin.x = screenFrame.midX - defaultFrame.width / 2
            defaultFrame.origin.y = screenFrame.minY + screenFrame.height * 0.13
            panel.setFrame(
                constrainedWindowFrame(defaultFrame, minimumSize: NSSize(width: 420, height: 160)),
                display: false
            )
        }

        subtitlePanel = panel
        subtitlePanelContentView = content
        subtitleScrollView = scrollView
        subtitleTranscriptView = textView
        subtitleOverlayLabel = overlayLabel
        subtitleJumpToLatestButton = jumpButton
        subtitleDragHandleView = dragHandle
        subtitleDragGripView = handlePill
        subtitleControlRow = controlRow
        subtitleTextOnlyButton = textOnlyButton
        subtitleCloseButton = closeButton
        applySubtitleStyle()
        syncSubtitlePanel()
    }

    @objc private func showSubtitlePanel() {
        buildSubtitlePanelIfNeeded()
        subtitlePanel?.orderFront(nil)
    }

    @objc private func hideSubtitlePanel() {
        subtitlePanel?.orderOut(nil)
        appendLog("Subtitle panel hidden.")
    }

    @objc private func toggleSubtitleTextOnlyMode() {
        subtitleTextOnlyMode.toggle()
        applySubtitleStyle()
        saveSubtitlePreferences()
        appendLog(subtitleTextOnlyMode ? "Subtitle panel switched to text-only mode." : "Subtitle panel restored to panel mode.")
    }

    @objc private func jumpSubtitleToLatest() {
        scrollSubtitleToLatest()
        subtitleHasUnreadContent = false
        updateSubtitleJumpButton()
    }

    @objc private func subtitleWindowBehaviorChanged(_ sender: NSButton) {
        subtitleAlwaysOnTop = subtitleAlwaysOnTopButton?.state == .on
        subtitlePositionLocked = subtitleLockPositionButton?.state == .on
        applySubtitleWindowBehavior()
        saveSubtitlePreferences()
    }

    @objc private func showDiagnostics() {
        if let diagnosticsWindow {
            diagnosticsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(Brand.name) Diagnostics"
        window.center()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.string = diagnosticLines.joined()
        scrollView.documentView = textView
        logView = textView

        let content = NSView()
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)
        ])
        window.contentView = content
        diagnosticsWindow = window
        window.makeKeyAndOrderFront(nil)
        textView.scrollToEndOfDocument(nil)
    }

    @objc private func showAppearanceSettings() {
        let alert = NSAlert()
        alert.messageText = "高级外观"
        alert.informativeText = "这些设置会覆盖当前主题预设，并自动保存。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "完成")

        let fontSlider = makeSlider(min: 18, max: 36, value: Double(primarySubtitleFontSize), action: #selector(subtitleStyleChanged(_:)))
        let panelOpacitySlider = makeSlider(min: 0.35, max: 1.0, value: Double(subtitlePanelOpacity), action: #selector(subtitleStyleChanged(_:)))
        let backgroundOpacitySlider = makeSlider(min: 0.0, max: 0.95, value: Double(subtitleBackgroundOpacity), action: #selector(subtitleStyleChanged(_:)))
        let widthSlider = makeSlider(min: 640, max: 1280, value: Double(subtitlePanelWidth), action: #selector(subtitleStyleChanged(_:)))
        let textBackingOpacitySlider = makeSlider(min: 0.0, max: 0.75, value: Double(subtitleTextBackingOpacity), action: #selector(subtitleStyleChanged(_:)))
        let primaryColorWell = makeColorWell(color: primarySubtitleTextColor, action: #selector(subtitleColorChanged(_:)))
        let secondaryColorWell = makeColorWell(color: secondarySubtitleTextColor, action: #selector(subtitleColorChanged(_:)))
        let backgroundColorWell = makeColorWell(color: subtitleBackgroundColor, action: #selector(subtitleColorChanged(_:)))
        let textBackingColorWell = makeColorWell(color: subtitleTextBackingColor, action: #selector(subtitleColorChanged(_:)))

        self.primaryFontSizeSlider = fontSlider
        self.panelOpacitySlider = panelOpacitySlider
        self.backgroundOpacitySlider = backgroundOpacitySlider
        self.panelWidthSlider = widthSlider
        self.textBackingOpacitySlider = textBackingOpacitySlider
        self.primaryTextColorWell = primaryColorWell
        self.secondaryTextColorWell = secondaryColorWell
        self.backgroundColorWell = backgroundColorWell
        self.textBackingColorWell = textBackingColorWell

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "字号"), fontSlider, NSTextField(labelWithString: "译文颜色"), primaryColorWell],
            [NSTextField(labelWithString: "宽度"), widthSlider, NSTextField(labelWithString: "原文颜色"), secondaryColorWell],
            [NSTextField(labelWithString: "浮窗透明"), panelOpacitySlider, NSTextField(labelWithString: "背景颜色"), backgroundColorWell],
            [NSTextField(labelWithString: "背景深度"), backgroundOpacitySlider, NSTextField(labelWithString: "底色颜色"), textBackingColorWell],
            [NSTextField(labelWithString: "文字底色"), textBackingOpacitySlider, NSTextField(labelWithString: ""), NSTextField(labelWithString: "")]
        ])
        grid.columnSpacing = 12
        grid.rowSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        for slider in [fontSlider, panelOpacitySlider, backgroundOpacitySlider, widthSlider, textBackingOpacitySlider] {
            slider.widthAnchor.constraint(equalToConstant: 190).isActive = true
        }

        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 190))
        wrapper.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            grid.topAnchor.constraint(equalTo: wrapper.topAnchor),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: wrapper.bottomAnchor)
        ])
        alert.accessoryView = wrapper
        alert.runModal()
        applySubtitleStyle()
        saveSubtitlePreferences()
    }

    @objc private func clearCaptionWindow() {
        resetCaptionContext()
        updateSubtitle("字幕已清空", secondary: nil, meta: "\(Brand.name) ready")
    }

    @objc private func openSessionsFolder() {
        let folder = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent(Brand.storageName, isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
            appendLog("Opened transcript sessions folder: \(folder.path)")
        } catch {
            appendLog("Could not open transcript sessions folder: \(error)")
            updateSubtitle("无法打开保存目录", secondary: "\(error)", meta: "Sessions")
        }
    }

    @objc private func subtitleStyleChanged(_ sender: NSSlider) {
        if sender === primaryFontSizeSlider {
            primarySubtitleFontSize = CGFloat(sender.doubleValue)
            secondarySubtitleFontSize = max(12, primarySubtitleFontSize * 0.62)
        } else if sender === panelOpacitySlider {
            subtitlePanelOpacity = CGFloat(sender.doubleValue)
        } else if sender === backgroundOpacitySlider {
            subtitleBackgroundOpacity = CGFloat(sender.doubleValue)
        } else if sender === panelWidthSlider {
            subtitlePanelWidth = CGFloat(sender.doubleValue)
        } else if sender === textBackingOpacitySlider {
            subtitleTextBackingOpacity = CGFloat(sender.doubleValue)
        }

        applySubtitleStyle()
        saveSubtitlePreferences()
    }

    @objc private func subtitleColorChanged(_ sender: NSColorWell) {
        if sender === primaryTextColorWell {
            primarySubtitleTextColor = sender.color
        } else if sender === secondaryTextColorWell {
            secondarySubtitleTextColor = sender.color
        } else if sender === backgroundColorWell {
            subtitleBackgroundColor = sender.color
        } else if sender === textBackingColorWell {
            subtitleTextBackingColor = sender.color
        }

        applySubtitleStyle()
        saveSubtitlePreferences()
    }

    @objc private func contentModeChanged(_ sender: NSSegmentedControl) {
        subtitleContentMode = SubtitleContentMode(rawValue: sender.selectedSegment) ?? .bilingual
        saveSubtitlePreferences()
        syncSubtitlePanel()
        let display = plainCaptionDisplay()
        updateSubtitle(display.primary, secondary: display.secondary.isEmpty ? nil : display.secondary, meta: subtitleMetaLabel.stringValue)
    }

    @objc private func themePresetChanged(_ sender: NSSegmentedControl) {
        subtitleThemePreset = SubtitleThemePreset(rawValue: sender.selectedSegment) ?? .dark
        applyThemePreset(subtitleThemePreset)
        saveSubtitlePreferences()
    }

    @objc private func fontPresetChanged(_ sender: NSSegmentedControl) {
        subtitleFontPreset = SubtitleFontPreset(rawValue: sender.selectedSegment) ?? .medium
        primarySubtitleFontSize = subtitleFontPreset.primarySize
        secondarySubtitleFontSize = max(12, primarySubtitleFontSize * 0.62)
        applySubtitleStyle()
        saveSubtitlePreferences()
    }

    @objc private func windowSizePresetChanged(_ sender: NSSegmentedControl) {
        subtitleWindowSizePreset = SubtitleWindowSizePreset(rawValue: sender.selectedSegment) ?? .comfortable
        let size = subtitleWindowSizePreset.size
        subtitlePanelWidth = size.width
        subtitlePanelHeight = size.height
        applySubtitleStyle()
        saveSubtitlePreferences()
    }

    private func applyThemePreset(_ preset: SubtitleThemePreset) {
        let colors = preset.colors
        primarySubtitleTextColor = colors.primary
        secondarySubtitleTextColor = colors.secondary
        subtitleBackgroundColor = colors.background
        subtitleTextBackingColor = colors.textBacking
        subtitleBackgroundOpacity = colors.backgroundOpacity
        subtitleTextBackingOpacity = colors.textBackingOpacity
        subtitlePanelOpacity = colors.panelOpacity
        applySubtitleStyle()
    }

    @objc private func paragraphModeChanged(_ sender: NSSegmentedControl) {
        paragraphMode = SubtitleParagraphMode(rawValue: sender.selectedSegment) ?? .balanced
        updateParagraphModeLabel()
        saveSubtitlePreferences()
        appendLog("Paragraph mode changed to \(paragraphMode.description). It applies to the next capture session.")
        updateSubtitleMeta("段落模式：\(paragraphMode.title)；重新开始捕获后完全生效")
    }

    @objc private func runtimeModeChanged(_ sender: NSSegmentedControl) {
        runtimeMode = TranslationRuntimeMode(rawValue: sender.selectedSegment) ?? .cloudAST
        updateParagraphModeLabel()
        updateCloudCredentialLabel()
        saveSubtitlePreferences()
        appendLog("Translation engine changed to \(runtimeMode.description). It applies to the next capture session.")

        if runtimeMode == .cloudAST && !CloudCredentialStore.hasVolcengineCredentials() {
            updateSubtitle(
                "需要配置豆包 AST",
                secondary: "把语音大模型服务的 API Key 填到第一栏；Access Token 通常留空。",
                meta: "Cloud mode"
            )
        } else {
            updateSubtitleMeta("引擎：\(runtimeMode.title)；重新开始捕获后完全生效")
        }
    }

    @objc private func configureCloudCredentials() {
        presentCloudCredentialDialog(startAfterSave: false)
    }

    @objc private func testCloudConnection() {
        guard cloudTestTask == nil else {
            appendLog("Cloud AST test is already running.")
            return
        }

        guard activeStream == nil else {
            updateSubtitle(
                "请先停止字幕",
                secondary: "测试连接不会发送 Chrome 音频，请停止当前捕获后再测。",
                meta: "Cloud test"
            )
            return
        }

        guard let credentials = CloudCredentialStore.loadVolcengineCredentials() else {
            updateSubtitle(
                "需要配置豆包 AST",
                secondary: "先填语音大模型 API Key，再点测试连接。",
                meta: "Cloud test"
            )
            presentCloudCredentialDialog(startAfterSave: false)
            return
        }

        cloudTestButton?.isEnabled = false
        cloudCredentialLabel.stringValue = "Cloud: testing..."
        updateSubtitle(
            "正在测试豆包 AST...",
            secondary: "只验证 WebSocket 和 StartSession，不发送 Chrome 音频。",
            meta: "Cloud test"
        )
        appendLog("Testing Cloud AST credentials with StartSession only...")

        let startedAt = Date()
        cloudTestTask = Task { [weak self] in
            let client = VolcengineASTClient { [weak self] event in
                Task { @MainActor in
                    self?.handleCloudTestEvent(event)
                }
            }

            do {
                try await client.start(credentials: credentials, timeoutSeconds: 12)
                await client.stop()
                await MainActor.run {
                    self?.finishCloudConnectionTest(
                        success: true,
                        message: "StartSession 成功，AST 服务可用。",
                        latency: Date().timeIntervalSince(startedAt)
                    )
                }
            } catch {
                await client.stop()
                await MainActor.run {
                    self?.finishCloudConnectionTest(
                        success: false,
                        message: "\(error)",
                        latency: Date().timeIntervalSince(startedAt)
                    )
                }
            }
        }
    }

    private func handleCloudTestEvent(_ event: VolcengineASTEvent) {
        switch event {
        case .connected:
            appendLog("Cloud test: WebSocket connected.")
        case .sessionStarted:
            appendLog("Cloud test: SessionStarted received.")
        case .failed(let message):
            appendLog("Cloud test server event: \(message)")
        case .log(let message):
            appendLog("Cloud test: \(message)")
        default:
            break
        }
    }

    private func finishCloudConnectionTest(success: Bool, message: String, latency: TimeInterval) {
        cloudTestTask = nil
        cloudTestButton?.isEnabled = true

        if success {
            let duration = String(format: "%.2f", latency)
            cloudCredentialLabel.stringValue = "Cloud: test OK \(duration)s"
            updateSubtitle(
                "豆包 AST 连接正常",
                secondary: message,
                meta: "Cloud test OK \(duration)s"
            )
            appendLog("Cloud AST test passed in \(duration)s.")
        } else {
            cloudCredentialLabel.stringValue = "Cloud: test failed"
            updateSubtitle(
                "豆包 AST 连接失败",
                secondary: message,
                meta: "检查 API Key、项目、服务开通、余额和网络"
            )
            appendLog("Cloud AST test failed: \(message)")
        }
    }

    private func updateParagraphModeLabel() {
        modeLabel.stringValue = "\(runtimeMode.title) / \(paragraphMode.title)"
        modeLabel.toolTip = modeLabel.stringValue
    }

    private func updateCloudCredentialLabel() {
        let configured = CloudCredentialStore.hasVolcengineCredentials()
        let cost = cloudEstimatedCostCNY > 0 ? "  Est ¥\(String(format: "%.4f", cloudEstimatedCostCNY))" : ""
        cloudCredentialLabel.stringValue = configured ? "Cloud: config ready\(cost)" : "Cloud: missing key"
    }

    private func presentCloudCredentialDialog(startAfterSave: Bool) {
        let existing = CloudCredentialStore.loadVolcenginePartialCredentials()
        let alert = NSAlert()
        alert.messageText = "配置豆包同声传译 AST 2.0"
        alert.informativeText = "本版本固定使用豆包语音同声传译 AST 2.0，不需要选择方舟文本模型。把语音大模型服务「API Key 管理」里的 API Key 填到第一栏；新版按 X-Api-Key 发送。不要填火山方舟 API Key，也不要填 IAM 的 AccessKey ID/Secret。Access Token 通常留空，只有旧控制台明确要求 X-Api-App-Key + X-Api-Access-Key 时才填。密钥保存到本机配置文件，不再使用 macOS Keychain。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let appKeyField = NSTextField(string: existing.appKey)
        appKeyField.placeholderString = "必填：语音大模型 API Key"
        let tokenField = NSSecureTextField(string: "")
        tokenField.placeholderString = existing.accessToken.isEmpty ? "可选：旧控制台 Access Token / X-Api-Access-Key" : "已保存旧 Access Token，留空将清空"

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "API Key"), appKeyField],
            [NSTextField(labelWithString: "Access Token"), tokenField]
        ])
        grid.columnSpacing = 10
        grid.rowSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        appKeyField.widthAnchor.constraint(equalToConstant: 360).isActive = true

        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 64))
        wrapper.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            grid.topAnchor.constraint(equalTo: wrapper.topAnchor),
            grid.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        alert.accessoryView = wrapper

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        do {
            let appKey = appKeyField.stringValue.localvTrimmed.isEmpty ? nil : appKeyField.stringValue
            let token = tokenField.stringValue.localvTrimmed.isEmpty ? nil : tokenField.stringValue
            try CloudCredentialStore.saveVolcengine(appKey: appKey, accessToken: token)
            updateCloudCredentialLabel()
            appendLog("Cloud AST credentials saved to local config file.")
            updateSubtitle(
                "密钥已保存",
                secondary: "建议先点测试连接，确认 API Key、项目和服务开通状态。",
                meta: "Local config"
            )

            if startAfterSave {
                startChromeCapture()
            }
        } catch {
            appendLog("Could not save Cloud AST credentials: \(error)")
            updateSubtitle("密钥保存失败", secondary: "\(error)", meta: "Local config")
        }
    }

    private func subtitleChromeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: title == "×" ? 15 : 11, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: title == "×" ? 28 : 42).isActive = true
        return button
    }

    private func applySubtitleStyle() {
        subtitleLabel.font = NSFont.systemFont(ofSize: max(14, primarySubtitleFontSize - 2), weight: .semibold)
        subtitleLabel.textColor = primarySubtitleTextColor
        subtitleLabel.maximumNumberOfLines = 7
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleSecondaryLabel.font = NSFont.systemFont(ofSize: secondarySubtitleFontSize, weight: .regular)
        subtitleSecondaryLabel.textColor = secondarySubtitleTextColor
        subtitleSecondaryLabel.maximumNumberOfLines = 4
        subtitleSecondaryLabel.lineBreakMode = .byWordWrapping
        subtitlePanel?.alphaValue = subtitleTextOnlyMode ? 1.0 : subtitlePanelOpacity
        let effectiveBackgroundOpacity: CGFloat = subtitleTextOnlyMode ? 0 : subtitleBackgroundOpacity
        subtitlePanelContentView?.layer?.backgroundColor = subtitleBackgroundColor.withAlphaComponent(effectiveBackgroundOpacity).cgColor
        subtitlePanelContentView?.layer?.cornerRadius = subtitleTextOnlyMode ? 0 : 18
        subtitleScrollView?.isHidden = subtitleTextOnlyMode
        subtitleScrollView?.hasVerticalScroller = !subtitleTextOnlyMode
        subtitleOverlayLabel?.isHidden = !subtitleTextOnlyMode
        subtitleOverlayLabel?.drawsBackground = false
        subtitleOverlayLabel?.backgroundColor = .clear
        subtitleOverlayLabel?.maximumNumberOfLines = 14
        subtitlePanel?.hasShadow = !subtitleTextOnlyMode
        subtitleTextOnlyButton?.title = subtitleTextOnlyMode ? "面板" : "纯字"
        subtitleDragGripView?.isHidden = subtitleTextOnlyMode
        applyTextBacking(to: subtitleLabel)
        applyTextBacking(to: subtitleSecondaryLabel)
        subtitleTranscriptView?.textColor = primarySubtitleTextColor
        subtitleTranscriptView?.textContainerInset = NSSize(width: 18, height: 22)
        updateDragHandleAppearance()
        updateSubtitleControlVisibility()
        applySubtitleWindowBehavior()

        if let panel = subtitlePanel {
            var frame = panel.frame
            let centerX = frame.midX
            frame.size.width = subtitlePanelWidth
            frame.size.height = preferredSubtitlePanelHeight()
            frame.origin.x = centerX - frame.size.width / 2
            panel.setFrame(constrainedWindowFrame(frame, minimumSize: NSSize(width: 420, height: 160)), display: true, animate: false)
        }
        syncSubtitlePanel()
    }

    private func applySubtitleWindowBehavior() {
        subtitlePanel?.level = subtitleAlwaysOnTop ? .floating : .normal
        subtitlePanel?.isMovableByWindowBackground = !subtitlePositionLocked
        subtitleDragHandleView?.canDragWindow = !subtitlePositionLocked
        subtitlePanel?.hasShadow = !subtitleTextOnlyMode
    }

    private func updateDragHandleAppearance() {
        guard let handle = subtitleDragHandleView else { return }
        for subview in handle.subviews {
            subview.layer?.backgroundColor = (subtitlePositionLocked
                ? secondarySubtitleTextColor.withAlphaComponent(0.18)
                : primarySubtitleTextColor.withAlphaComponent(0.36)).cgColor
        }
    }

    private func preferredSubtitlePanelHeight() -> CGFloat {
        subtitleTextOnlyMode ? min(max(subtitlePanelHeight, 260), 360) : subtitlePanelHeight
    }

    private func applyTextBacking(to label: NSTextField) {
        let enabled = !subtitleTextOnlyMode && subtitleTextBackingOpacity > 0.01
        label.drawsBackground = enabled
        label.backgroundColor = enabled
            ? subtitleTextBackingColor.withAlphaComponent(subtitleTextBackingOpacity)
            : .clear
    }

    private func loadSubtitlePreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "subtitle.themePreset") != nil,
           let preset = SubtitleThemePreset(rawValue: defaults.integer(forKey: "subtitle.themePreset")) {
            subtitleThemePreset = preset
            let colors = preset.colors
            primarySubtitleTextColor = colors.primary
            secondarySubtitleTextColor = colors.secondary
            subtitleBackgroundColor = colors.background
            subtitleTextBackingColor = colors.textBacking
            subtitleBackgroundOpacity = colors.backgroundOpacity
            subtitleTextBackingOpacity = colors.textBackingOpacity
            subtitlePanelOpacity = colors.panelOpacity
        }
        if defaults.object(forKey: "subtitle.fontPreset") != nil,
           let preset = SubtitleFontPreset(rawValue: defaults.integer(forKey: "subtitle.fontPreset")) {
            subtitleFontPreset = preset
            primarySubtitleFontSize = preset.primarySize
            secondarySubtitleFontSize = max(12, primarySubtitleFontSize * 0.62)
        }
        if defaults.object(forKey: "subtitle.windowSizePreset") != nil,
           let preset = SubtitleWindowSizePreset(rawValue: defaults.integer(forKey: "subtitle.windowSizePreset")) {
            subtitleWindowSizePreset = preset
            let size = preset.size
            subtitlePanelWidth = size.width
            subtitlePanelHeight = size.height
        }
        if defaults.object(forKey: "subtitle.primaryFontSize") != nil {
            primarySubtitleFontSize = CGFloat(defaults.double(forKey: "subtitle.primaryFontSize"))
            secondarySubtitleFontSize = max(12, primarySubtitleFontSize * 0.62)
        }
        if defaults.object(forKey: "subtitle.panelOpacity") != nil {
            subtitlePanelOpacity = CGFloat(defaults.double(forKey: "subtitle.panelOpacity"))
        }
        if defaults.object(forKey: "subtitle.backgroundOpacity") != nil {
            subtitleBackgroundOpacity = CGFloat(defaults.double(forKey: "subtitle.backgroundOpacity"))
        }
        if defaults.object(forKey: "subtitle.panelWidth") != nil {
            subtitlePanelWidth = CGFloat(defaults.double(forKey: "subtitle.panelWidth"))
        }
        if defaults.object(forKey: "subtitle.panelHeight") != nil {
            subtitlePanelHeight = CGFloat(defaults.double(forKey: "subtitle.panelHeight"))
        }
        if defaults.object(forKey: "subtitle.textBackingOpacity") != nil {
            subtitleTextBackingOpacity = CGFloat(defaults.double(forKey: "subtitle.textBackingOpacity"))
        }
        primarySubtitleTextColor = loadColorPreference(
            key: "subtitle.primaryTextColor",
            fallback: primarySubtitleTextColor
        )
        secondarySubtitleTextColor = loadColorPreference(
            key: "subtitle.secondaryTextColor",
            fallback: secondarySubtitleTextColor
        )
        subtitleBackgroundColor = loadColorPreference(
            key: "subtitle.backgroundColor",
            fallback: subtitleBackgroundColor
        )
        subtitleTextBackingColor = loadColorPreference(
            key: "subtitle.textBackingColor",
            fallback: subtitleTextBackingColor
        )
        if defaults.object(forKey: "subtitle.paragraphMode") != nil,
           let mode = SubtitleParagraphMode(rawValue: defaults.integer(forKey: "subtitle.paragraphMode")) {
            paragraphMode = mode
        }
        if defaults.object(forKey: "subtitle.contentMode") != nil,
           let mode = SubtitleContentMode(rawValue: defaults.integer(forKey: "subtitle.contentMode")) {
            subtitleContentMode = mode
        }
        if defaults.object(forKey: "subtitle.alwaysOnTop") != nil {
            subtitleAlwaysOnTop = defaults.bool(forKey: "subtitle.alwaysOnTop")
        }
        if defaults.object(forKey: "subtitle.positionLocked") != nil {
            subtitlePositionLocked = defaults.bool(forKey: "subtitle.positionLocked")
        }
        if defaults.object(forKey: "subtitle.textOnlyMode") != nil {
            subtitleTextOnlyMode = defaults.bool(forKey: "subtitle.textOnlyMode")
        }
        if defaults.object(forKey: "translation.runtimeMode") != nil,
           let mode = TranslationRuntimeMode(rawValue: defaults.integer(forKey: "translation.runtimeMode")) {
            runtimeMode = mode
        }
    }

    private func saveSubtitlePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(Double(primarySubtitleFontSize), forKey: "subtitle.primaryFontSize")
        defaults.set(Double(subtitlePanelOpacity), forKey: "subtitle.panelOpacity")
        defaults.set(Double(subtitleBackgroundOpacity), forKey: "subtitle.backgroundOpacity")
        defaults.set(Double(subtitlePanelWidth), forKey: "subtitle.panelWidth")
        defaults.set(Double(subtitlePanelHeight), forKey: "subtitle.panelHeight")
        defaults.set(Double(subtitleTextBackingOpacity), forKey: "subtitle.textBackingOpacity")
        saveColorPreference(primarySubtitleTextColor, key: "subtitle.primaryTextColor")
        saveColorPreference(secondarySubtitleTextColor, key: "subtitle.secondaryTextColor")
        saveColorPreference(subtitleBackgroundColor, key: "subtitle.backgroundColor")
        saveColorPreference(subtitleTextBackingColor, key: "subtitle.textBackingColor")
        defaults.set(paragraphMode.rawValue, forKey: "subtitle.paragraphMode")
        defaults.set(subtitleContentMode.rawValue, forKey: "subtitle.contentMode")
        defaults.set(subtitleThemePreset.rawValue, forKey: "subtitle.themePreset")
        defaults.set(subtitleFontPreset.rawValue, forKey: "subtitle.fontPreset")
        defaults.set(subtitleWindowSizePreset.rawValue, forKey: "subtitle.windowSizePreset")
        defaults.set(subtitleAlwaysOnTop, forKey: "subtitle.alwaysOnTop")
        defaults.set(subtitlePositionLocked, forKey: "subtitle.positionLocked")
        defaults.set(subtitleTextOnlyMode, forKey: "subtitle.textOnlyMode")
        defaults.set(runtimeMode.rawValue, forKey: "translation.runtimeMode")
    }

    private func loadColorPreference(key: String, fallback: NSColor) -> NSColor {
        guard let data = UserDefaults.standard.data(forKey: key),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else {
            return fallback
        }
        return color
    }

    private func saveColorPreference(_ color: NSColor, key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: color,
            requiringSecureCoding: false
        ) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    @objc private func requestCapturePermission() {
        appendLog("Checking Screen & System Audio Recording permission...")
        updateSubtitle("正在申请系统音频权限...", secondary: nil, meta: "如果系统弹窗出现，请选择允许")

        Task { @MainActor in
            let granted = await requestScreenCaptureAccess(openSettingsOnFailure: true)
            if granted {
                appendLog("Screen & System Audio Recording permission is ready.")
                updateSubtitle("权限已就绪", secondary: nil, meta: "可以开始 Chrome 字幕")
            }
        }
    }

    @objc private func startChromeCapture() {
        guard activeStream == nil else {
            appendLog("Capture is already running.")
            return
        }

        let selectedMode = runtimeMode
        let cloudCredentials: VolcengineCredentials?
        if selectedMode == .cloudAST {
                guard let credentials = CloudCredentialStore.loadVolcengineCredentials() else {
                appendLog("Cloud AST credentials are missing.")
                updateSubtitle(
                    "需要配置豆包 AST",
                    secondary: "把语音大模型服务的 API Key 填到第一栏；保存后会自动继续开始 Chrome 字幕。",
                    meta: "Cloud mode"
                )
                presentCloudCredentialDialog(startAfterSave: true)
                return
            }
            cloudCredentials = credentials
        } else {
            cloudCredentials = nil
        }

        guard CGPreflightScreenCaptureAccess() else {
            appendLog("Capture permission is not ready. Requesting permission before starting...")
            updateSubtitle("需要系统音频权限", secondary: nil, meta: "请在弹窗中允许，或在设置里打开 \(Brand.name)")

            Task { @MainActor in
                let granted = await requestScreenCaptureAccess(openSettingsOnFailure: true)
                if granted {
                    startChromeCapture()
                }
            }
            return
        }

        do {
            transcriptPersistence = try TranscriptPersistence.start(
                sourceName: "Google Chrome",
                mode: selectedMode.transcriptMode,
                models: selectedMode == .local
                    ? ModelSelection(asrModel: asrEngine.modelName, translationModel: translator.preferredModelName)
                    : selectedMode.models
            )
            persistedSubtitleCount = 0
            if let transcriptPersistence {
                appendLog("Transcript session: \(transcriptPersistence.markdownURL.path)")
            }
        } catch {
            appendLog("Transcript persistence unavailable: \(error)")
        }

        setRunningUI(true)
        showSubtitlePanel()
        activeRuntimeMode = selectedMode
        sessionStartedAt = Date()
        speechWindowCount = 0
        hasRenderedSubtitle = false
        cloudCurrentSourceText = ""
        cloudCurrentTranslationText = ""
        cloudEstimatedCostCNY = 0
        resetCaptionContext()
        updateCloudCredentialLabel()
        updateSubtitle("正在监听 Chrome 音频...", secondary: nil, meta: "等待语音片段")
        appendLog("Starting Chrome app-level capture...")
        if selectedMode == .local {
            warmUpInference()
        } else {
            appendLog("Cloud AST mode: WhisperKit and Ollama will stay unloaded for this session.")
        }

        Task {
            await startCaptureTask(mode: selectedMode, cloudCredentials: cloudCredentials)
        }
    }

    @objc private func stopCapture() {
        guard let stream = activeStream else {
            finishStoppedCapture()
            return
        }

        appendLog("Stopping capture...")
        Task {
            do {
                try await stream.stopCaptureAsync()
                await MainActor.run {
                    self.finishStoppedCapture()
                }
            } catch {
                await MainActor.run {
                    self.appendLog("Stop failed: \(error)")
                    self.finishStoppedCapture()
                }
            }
        }
    }

    private func startCaptureTask(
        mode: TranslationRuntimeMode,
        cloudCredentials: VolcengineCredentials?
    ) async {
        do {
            let content = try await ShareableContentLoader.load()

            guard let display = content.displays.first else {
                throw AppError.noDisplayAvailable
            }

            guard let chrome = selectChrome(from: content.applications) else {
                throw AppError.chromeNotFound
            }

            appendLog("Selected source: \(chrome.applicationName) | \(chrome.bundleIdentifier) | pid \(chrome.processID)")

            let cloudClient: VolcengineASTClient?
            if mode == .cloudAST {
                guard let cloudCredentials else {
                    throw AppError.translationFailed("Cloud AST credentials are missing")
                }
                appendLog("Connecting Cloud AST session...")
                let client = VolcengineASTClient { [weak self] event in
                    Task { @MainActor in
                        self?.handle(event)
                    }
                }
                activeCloudClient = client
                try await client.start(credentials: cloudCredentials)
                cloudClient = client
                appendLog("Cloud AST session is ready.")
            } else {
                cloudClient = nil
            }

            let probe = AudioProbe(
                configuration: paragraphMode.configuration,
                audioSink: { chunk in
                    if let cloudClient {
                        Task {
                            await cloudClient.send(chunk)
                        }
                    }
                }
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }

            let filter = SCContentFilter(
                display: display,
                including: [chrome],
                exceptingWindows: []
            )

            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 16_000
            configuration.channelCount = 1
            configuration.width = 2
            configuration.height = 2
            configuration.queueDepth = 3
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            configuration.showsCursor = false

            let stream = SCStream(filter: filter, configuration: configuration, delegate: probe)
            try stream.addStreamOutput(
                probe,
                type: .audio,
                sampleHandlerQueue: DispatchQueue(label: "localv.app.audio")
            )

            activeStream = stream
            activeProbe = probe

            try await stream.startCaptureAsync()
            appendLog("Capture started. Play a Space, YouTube, Twitch, or any Chrome audio.")
            captureLabel.stringValue = "监听中"
            captureLabel.toolTip = captureLabel.stringValue
        } catch {
            appendLog("Capture failed: \(error)")
            appendLog("Permission path: System Settings -> Privacy & Security -> Screen & System Audio Recording -> \(Brand.name).")
            finishStoppedCapture()
        }
    }

    private func requestScreenCaptureAccess(openSettingsOnFailure: Bool) async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        appendLog("Showing macOS permission request for Screen & System Audio Recording...")
        let granted = CGRequestScreenCaptureAccess()

        if granted || CGPreflightScreenCaptureAccess() {
            return true
        }

        appendLog("macOS did not grant permission from the request prompt.")
        appendLog("If no prompt appeared, macOS has already recorded a previous choice; enable \(Brand.name) manually in Settings.")
        appendLog("To make macOS show the prompt again, reset: tccutil reset ScreenCapture app.livesub.mac")
        updateSubtitle(
            "还没有权限",
            secondary: "如果没有弹窗，说明系统已经记录过选择。请在设置里打开 \(Brand.name)，或重置后再点申请权限。",
            meta: "System Settings -> Privacy & Security -> Screen & System Audio Recording"
        )

        if openSettingsOnFailure {
            openScreenCaptureSettings()
        }

        return false
    }

    private func openScreenCaptureSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func selectChrome(from applications: [SCRunningApplication]) -> SCRunningApplication? {
        applications.first { $0.bundleIdentifier == "com.google.Chrome" }
            ?? applications.first { $0.applicationName.localizedCaseInsensitiveContains("Chrome") }
    }

    private func handle(_ event: AudioProbeEvent) {
        switch event {
        case .firstBuffer(let samples, let sampleRate, let channelCount):
            appendLog("First audio buffer: samples=\(samples), format=\(sampleRate)Hz/\(channelCount)ch")
        case .speechChanged(let isSpeech, let rms, let time):
            vadLabel.stringValue = "VAD: \(isSpeech ? "speech" : "silence")"
            rmsLabel.stringValue = "RMS: \(String(format: "%.5f", rms))"
            appendLog("VAD transition: speech=\(isSpeech), rms=\(String(format: "%.5f", rms)), at=\(String(format: "%.2f", time))s")
        case .speechWindow(let window):
            speechWindowCount += 1
            windowLabel.stringValue = "Windows: \(speechWindowCount)"
            if activeRuntimeMode == .cloudAST {
                return
            }
            if !hasRenderedSubtitle && activeInferenceTask == nil {
                updateSubtitleMeta("已捕获语音，准备转写 \(String(format: "%.2f", window.duration))s 音频")
            }
            if window.kind == .final {
                appendLog("Final speech window: segment=\(window.segmentIndex), revision=\(window.revision), duration=\(String(format: "%.2f", window.duration))s")
            }
            enqueueInference(for: window)
        case .stats(let buffers, let samples, let rms, let isSpeech, let ringDuration):
            bufferLabel.stringValue = "Buffers: \(buffers) / samples: \(samples)"
            rmsLabel.stringValue = "RMS: \(String(format: "%.5f", rms))"
            vadLabel.stringValue = "VAD: \(isSpeech ? "speech" : "silence")"
            captureLabel.stringValue = "监听中 · 缓冲 \(String(format: "%.1f", ringDuration))s"
            captureLabel.toolTip = captureLabel.stringValue
        case .stoppedWithError(let message):
            appendLog("ScreenCaptureKit stopped with error: \(message)")
            finishStoppedCapture()
        }
    }

    private func handle(_ event: VolcengineASTEvent) {
        switch event {
        case .connected:
            appendLog("Cloud AST WebSocket connected; waiting for session start...")
            updateSubtitleMeta("Cloud AST connecting")
        case .sessionStarted:
            appendLog("Cloud AST session started.")
            updateSubtitle("云端字幕已就绪", secondary: nil, meta: "Doubao AST en -> zh")
        case .sourceSubtitle(let subtitle):
            cloudCurrentSourceText = subtitle.text.localvTrimmed
            guard !cloudCurrentSourceText.isEmpty else { return }
            if cloudCurrentTranslationText.isEmpty {
                updateLiveCaption(
                    cloudCurrentSourceText,
                    secondary: nil,
                    meta: cloudMeta(prefix: "ASR", phase: subtitle.phase),
                    commit: false
                )
            } else {
                updateLiveCaption(
                    cloudCurrentTranslationText,
                    secondary: cloudCurrentSourceText,
                    meta: cloudMeta(prefix: "AST", phase: subtitle.phase),
                    commit: false
                )
            }
        case .translationSubtitle(let subtitle):
            cloudCurrentTranslationText = subtitle.text.localvTrimmed
            guard !cloudCurrentTranslationText.isEmpty else { return }
            hasRenderedSubtitle = true
            updateLiveCaption(
                cloudCurrentTranslationText,
                secondary: cloudCurrentSourceText.isEmpty ? nil : cloudCurrentSourceText,
                meta: cloudMeta(prefix: "AST", phase: subtitle.phase),
                commit: subtitle.phase == .final
            )

            if subtitle.phase == .final {
                persistCloudSubtitle(
                    sourceText: cloudCurrentSourceText,
                    translatedText: cloudCurrentTranslationText,
                    startTime: subtitle.startTime,
                    endTime: subtitle.endTime
                )
                cloudCurrentSourceText = ""
                cloudCurrentTranslationText = ""
            }
        case .usage(let usage):
            cloudEstimatedCostCNY += usage.estimatedCNY
            updateCloudCredentialLabel()
            appendLog("Cloud usage: \(usage.tokenQuantities), est ¥\(String(format: "%.4f", cloudEstimatedCostCNY))")
        case .finished:
            appendLog("Cloud AST session finished.")
        case .failed(let message):
            appendLog("Cloud AST failed: \(message)")
            updateSubtitle("Cloud AST failed.", secondary: message, meta: "切回本地或检查豆包权限")
        case .log(let message):
            appendLog(message)
        }
    }

    private func cloudMeta(prefix: String, phase: CloudSubtitle.Phase) -> String {
        let phaseText: String
        switch phase {
        case .start: phaseText = "start"
        case .partial: phaseText = "partial"
        case .final: phaseText = "final"
        }
        return "\(prefix) Doubao AST \(phaseText)"
    }

    private func enqueueInference(for window: SpeechWindow) {
        let minimumDuration = window.kind == .partial
            ? paragraphMode.minimumPartialInferenceDuration
            : 0.8

        guard window.duration >= minimumDuration else {
            return
        }

        if activeInferenceTask != nil {
            if shouldReplacePendingWindow(with: window) {
                pendingInferenceWindow = window
            }
            return
        }

        runInference(for: window)
    }

    private func runInference(for window: SpeechWindow) {
        if !hasRenderedSubtitle {
            updateSubtitle(
                "正在生成字幕...",
                secondary: nil,
                meta: "\(String(format: "%.2f", window.duration))s 音频 -> WhisperKit"
            )
        } else {
            updateSubtitleMeta("正在更新字幕：\(String(format: "%.2f", window.duration))s 音频 -> WhisperKit")
        }
        appendLog("ASR started: kind=\(window.kind.rawValue), segment=\(window.segmentIndex), revision=\(window.revision), duration=\(String(format: "%.2f", window.duration))s")

        activeInferenceTask = Task { [asrEngine, translator] in
            do {
                let transcript = try await asrEngine.transcribe(window)
                let translation = try? await translator.translate(transcript.englishText)

                await MainActor.run {
                    let chinese = translation?.chineseText
                    let primary = ((chinese?.isEmpty == false ? chinese : nil) ?? transcript.englishText).localvTrimmed
                    let secondary = chinese?.isEmpty == false ? transcript.englishText.localvTrimmed : nil
                    let meta = [
                        "WhisperKit \(transcript.modelName)",
                        translation.map { "Ollama \($0.modelName)" } ?? "Ollama unavailable",
                        "\(String(format: "%.2f", transcript.latencySeconds))s ASR"
                    ].joined(separator: " | ")

                    if primary.isEmpty {
                        self.updateSubtitleMeta("这段没有识别出稳定文本，继续听")
                    } else {
                        self.hasRenderedSubtitle = true
                        self.updateLiveCaption(
                            primary,
                            secondary: secondary,
                            meta: meta,
                            commit: window.kind == .final
                        )
                    }
                    self.appendLog("ASR: \(transcript.englishText)")
                    if let translation {
                        self.appendLog("ZH: \(translation.chineseText)")
                    }
                    self.persist(
                        transcript: transcript,
                        translation: translation,
                        window: window
                    )
                    self.finishInferenceTask()
                }
            } catch {
                await MainActor.run {
                    self.appendLog("ASR failed: \(error)")
                    self.updateSubtitle("ASR failed.", secondary: nil, meta: "\(error)")
                    self.finishInferenceTask()
                }
            }
        }
    }

    private func finishInferenceTask() {
        activeInferenceTask = nil

        if let next = pendingInferenceWindow {
            pendingInferenceWindow = nil
            runInference(for: next)
        }
    }

    private func updateLiveCaption(
        _ text: String,
        secondary: String? = nil,
        meta: String,
        commit: Bool
    ) {
        let translation = text.localvTrimmed
        let source = (secondary ?? "").localvTrimmed

        if commit {
            appendCaptionBlock(CaptionBlock(translation: translation, source: source))
            captionCurrentBlock = CaptionBlock(translation: "", source: "")
        } else {
            captionCurrentBlock = CaptionBlock(translation: translation, source: source)
        }

        let display = plainCaptionDisplay()

        updateSubtitle(
            display.primary.isEmpty ? translation : display.primary,
            secondary: display.secondary.isEmpty ? nil : display.secondary,
            meta: meta
        )
    }

    private func resetCaptionContext() {
        captionBlocks.removeAll(keepingCapacity: true)
        captionCurrentBlock = CaptionBlock(translation: "", source: "")
        subtitleHasUnreadContent = false
        updateSubtitleJumpButton()
    }

    private func appendCaptionBlock(_ block: CaptionBlock) {
        let normalized = CaptionBlock(
            translation: block.translation.localvTrimmed,
            source: block.source.localvTrimmed
        )
        guard !normalized.translation.isEmpty || !normalized.source.isEmpty else { return }
        if captionBlocks.last?.translation == normalized.translation,
           captionBlocks.last?.source == normalized.source {
            return
        }
        captionBlocks.append(normalized)
        trimCaptionBlocks()
    }

    private func activeCaptionBlocks() -> [CaptionBlock] {
        var blocks = captionBlocks
        if !captionCurrentBlock.translation.isEmpty || !captionCurrentBlock.source.isEmpty {
            if blocks.last?.translation != captionCurrentBlock.translation ||
                blocks.last?.source != captionCurrentBlock.source {
                blocks.append(captionCurrentBlock)
            }
        }
        trimCaptionBlocks(&blocks)
        return blocks
    }

    private func plainCaptionDisplay() -> (primary: String, secondary: String) {
        let blocks = activeCaptionBlocks()
        switch subtitleContentMode {
        case .bilingual:
            return (
                blocks.map(\.translation).filter { !$0.isEmpty }.joined(separator: "\n"),
                blocks.map(\.source).filter { !$0.isEmpty }.joined(separator: "\n")
            )
        case .translationOnly:
            return (blocks.map(\.translation).filter { !$0.isEmpty }.joined(separator: "\n"), "")
        case .sourceOnly:
            return (blocks.map(\.source).filter { !$0.isEmpty }.joined(separator: "\n"), "")
        }
    }

    private func trimCaptionBlocks() {
        trimCaptionBlocks(&captionBlocks)
    }

    private func trimCaptionBlocks(_ blocks: inout [CaptionBlock]) {
        while blocks.count > 1,
              (captionCharacterCount(blocks) > 1_200 || blocks.count > 18) {
            blocks.removeFirst()
        }
    }

    private func captionCharacterCount(_ blocks: [CaptionBlock]) -> Int {
        blocks.reduce(0) { total, block in
            total + block.translation.count + block.source.count
        }
    }

    private func updateSubtitle(_ text: String, secondary: String? = nil, meta: String) {
        subtitleLabel.stringValue = text
        subtitleSecondaryLabel.stringValue = secondary ?? ""
        subtitleSecondaryLabel.isHidden = (secondary ?? "").isEmpty
        subtitleMetaLabel.stringValue = meta
        syncSubtitlePanel()
    }

    private func updateSubtitleMeta(_ meta: String) {
        subtitleMetaLabel.stringValue = meta
        syncSubtitlePanel()
    }

    private func shouldReplacePendingWindow(with window: SpeechWindow) -> Bool {
        guard let pendingInferenceWindow else {
            return true
        }

        if window.kind == .final && pendingInferenceWindow.kind == .partial {
            return true
        }

        if window.kind == .partial && pendingInferenceWindow.kind == .final {
            return window.segmentIndex > pendingInferenceWindow.segmentIndex + 1
        }

        if window.segmentIndex != pendingInferenceWindow.segmentIndex {
            return window.segmentIndex > pendingInferenceWindow.segmentIndex
        }

        return window.revision > pendingInferenceWindow.revision
    }

    private func syncSubtitlePanel() {
        guard let transcriptView = subtitleTranscriptView else { return }
        transcriptView.textStorage?.setAttributedString(renderSubtitleTranscript())
        subtitleOverlayLabel?.attributedStringValue = renderSubtitleOverlay()

        if subtitleTextOnlyMode {
            subtitleHasUnreadContent = false
        } else {
            scrollSubtitleToLatest()
            Task { @MainActor [weak self] in
                self?.scrollSubtitleToLatest()
            }
            subtitleHasUnreadContent = false
        }
        updateSubtitleJumpButton()
    }

    private func isSubtitleScrolledToBottom() -> Bool {
        guard let scrollView = subtitleScrollView else { return true }
        let clip = scrollView.contentView
        let maxY = clip.documentView?.bounds.height ?? 0
        return maxY - clip.bounds.maxY < 28
    }

    private func subtitleScrollDidMove() {
        if isSubtitleScrolledToBottom() {
            subtitleHasUnreadContent = false
            updateSubtitleJumpButton()
        }
    }

    private func scrollSubtitleToLatest() {
        guard let transcriptView = subtitleTranscriptView else { return }
        if let textContainer = transcriptView.textContainer {
            transcriptView.layoutManager?.ensureLayout(for: textContainer)
        }
        transcriptView.scrollRangeToVisible(NSRange(location: transcriptView.string.utf16.count, length: 0))

        guard let scrollView = subtitleScrollView,
              let documentView = scrollView.documentView
        else { return }

        documentView.layoutSubtreeIfNeeded()
        let clipView = scrollView.contentView
        let targetY = max(0, documentView.bounds.height - clipView.bounds.height)
        clipView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
    }

    private func updateSubtitleJumpButton() {
        subtitleJumpToLatestButton?.isHidden = subtitleTextOnlyMode || !subtitleHasUnreadContent
    }

    private func updateSubtitleControlVisibility() {
        if subtitleTextOnlyMode {
            subtitleControlRow?.isHidden = !subtitleHoverPaused
            subtitleControlRow?.alphaValue = subtitleHoverPaused ? 0.78 : 0
        } else {
            subtitleControlRow?.isHidden = false
            subtitleControlRow?.alphaValue = 1
        }
    }

    private func textOnlyCaptionBlocks() -> [CaptionBlock] {
        var blocks = activeCaptionBlocks()
        if blocks.isEmpty {
            blocks = [
                CaptionBlock(
                    translation: subtitleLabel.stringValue.localvTrimmed,
                    source: subtitleSecondaryLabel.stringValue.localvTrimmed
                )
            ]
        }

        while blocks.count > 1,
              (captionCharacterCount(blocks) > 520 || blocks.count > 6) {
            blocks.removeFirst()
        }
        return blocks
    }

    private func renderSubtitleOverlay() -> NSAttributedString {
        let output = NSMutableAttributedString()
        let blocks = textOnlyCaptionBlocks()

        for (index, block) in blocks.enumerated() {
            switch subtitleContentMode {
            case .bilingual:
                appendOverlayLine(block.translation, to: output, primary: true)
                appendOverlayLine(block.source, to: output, primary: false)
            case .translationOnly:
                appendOverlayLine(block.translation, to: output, primary: true)
            case .sourceOnly:
                appendOverlayLine(
                    block.source.isEmpty ? block.translation : block.source,
                    to: output,
                    primary: true
                )
            }

            if index < blocks.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }

        return output
    }

    private func appendOverlayLine(
        _ line: String,
        to output: NSMutableAttributedString,
        primary: Bool
    ) {
        let text = line.localvTrimmed
        guard !text.isEmpty else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = primary ? 3 : 1
        paragraph.paragraphSpacing = primary ? 4 : 10

        let font = primary
            ? NSFont.systemFont(ofSize: primarySubtitleFontSize, weight: .semibold)
            : NSFont.systemFont(ofSize: max(13, secondarySubtitleFontSize), weight: .medium)
        let color = primary ? primarySubtitleTextColor : secondarySubtitleTextColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .shadow: subtleOverlayShadow(for: color, primary: primary),
            .paragraphStyle: paragraph
        ]

        output.append(NSAttributedString(string: text + "\n", attributes: attributes))
    }

    private func subtleOverlayShadow(for color: NSColor, primary: Bool) -> NSShadow {
        let shadow = NSShadow()
        let luminance = subtitleTextLuminance(color)
        let shadowBase: NSColor = luminance < 0.45 ? .white : .black
        shadow.shadowColor = shadowBase.withAlphaComponent(primary ? 0.28 : 0.20)
        shadow.shadowOffset = NSSize(width: 0, height: luminance < 0.45 ? 1 : -1)
        shadow.shadowBlurRadius = primary ? 3 : 2
        return shadow
    }

    private func subtitleTextLuminance(_ color: NSColor) -> CGFloat {
        guard let rgbColor = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) else {
            return 1
        }
        return (0.2126 * rgbColor.redComponent)
            + (0.7152 * rgbColor.greenComponent)
            + (0.0722 * rgbColor.blueComponent)
    }

    private func renderSubtitleTranscript() -> NSAttributedString {
        let output = NSMutableAttributedString()
        var blocks = activeCaptionBlocks()
        let currentIsVisible = !captionCurrentBlock.translation.isEmpty || !captionCurrentBlock.source.isEmpty
        if blocks.isEmpty {
            blocks = [
                CaptionBlock(
                    translation: subtitleLabel.stringValue.localvTrimmed,
                    source: subtitleSecondaryLabel.stringValue.localvTrimmed
                )
            ]
        }

        for (index, block) in blocks.enumerated() {
            let isCurrent = currentIsVisible && index == blocks.count - 1
            switch subtitleContentMode {
            case .bilingual:
                appendTranscriptLine(block.translation, to: output, primary: true, isCurrent: isCurrent)
                appendTranscriptLine(block.source, to: output, primary: false, isCurrent: isCurrent)
            case .translationOnly:
                appendTranscriptLine(block.translation, to: output, primary: true, isCurrent: isCurrent)
            case .sourceOnly:
                appendTranscriptLine(
                    block.source.isEmpty ? block.translation : block.source,
                    to: output,
                    primary: true,
                    isCurrent: isCurrent
                )
            }

            if index < blocks.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }

        return output
    }

    private func appendTranscriptLine(
        _ line: String,
        to output: NSMutableAttributedString,
        primary: Bool,
        isCurrent: Bool
    ) {
        let text = line.localvTrimmed
        guard !text.isEmpty else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = primary ? 5 : 2
        paragraph.paragraphSpacing = primary ? (isCurrent ? 7 : 5) : 14
        paragraph.lineBreakMode = .byWordWrapping

        let font = primary
            ? NSFont.systemFont(ofSize: primarySubtitleFontSize, weight: isCurrent ? .bold : .semibold)
            : NSFont.systemFont(ofSize: secondarySubtitleFontSize, weight: .regular)
        let color = primary ? primarySubtitleTextColor : secondarySubtitleTextColor

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if isCurrent && !subtitleTextOnlyMode {
            attributes[.backgroundColor] = NSColor.controlAccentColor.withAlphaComponent(primary ? 0.22 : 0.12)
        } else if !subtitleTextOnlyMode && subtitleTextBackingOpacity > 0.01 {
            attributes[.backgroundColor] = subtitleTextBackingColor.withAlphaComponent(subtitleTextBackingOpacity)
        }

        output.append(NSAttributedString(string: text + "\n", attributes: attributes))
    }

    private func setRunningUI(_ isRunning: Bool) {
        startButton?.isEnabled = !isRunning
        stopButton?.isEnabled = isRunning
        captureLabel.stringValue = isRunning ? "启动中" : "未启动"
        captureLabel.toolTip = captureLabel.stringValue
    }

    private func finishStoppedCapture() {
        activeInferenceTask?.cancel()
        activeInferenceTask = nil
        pendingInferenceWindow = nil
        let persistence = transcriptPersistence
        let cloudClient = activeCloudClient
        transcriptPersistence = nil
        activeStream = nil
        activeProbe = nil
        activeCloudClient = nil
        activeRuntimeMode = nil
        hasRenderedSubtitle = false
        setRunningUI(false)
        updateSubtitle("Capture stopped.", secondary: nil, meta: "\(Brand.name) idle")
        appendLog("Capture stopped.")

        if let cloudClient {
            Task {
                await cloudClient.stop()
            }
        }

        if let persistence {
            Task {
                do {
                    try await persistence.finish()
                } catch {
                    await MainActor.run {
                        self.appendLog("Transcript close failed: \(error)")
                    }
                }
            }
        }
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        lastEventLabel.stringValue = message
        lastEventLabel.toolTip = message
        diagnosticLines.append(line)
        if diagnosticLines.count > 700 {
            diagnosticLines.removeFirst(diagnosticLines.count - 700)
        }
        logView?.textStorage?.append(NSAttributedString(string: line))
        logView?.scrollToEndOfDocument(nil)
    }

    private func warmUpInference() {
        Task { [asrEngine, translator] in
            let startedAt = Date()
            do {
                async let asrReady: Void = asrEngine.prepare()
                async let translationReady: Void = translator.prepare()
                _ = try await (asrReady, translationReady)
                await MainActor.run {
                    self.appendLog("Inference warm-up ready in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s.")
                }
            } catch {
                await MainActor.run {
                    self.appendLog("Inference warm-up skipped: \(error)")
                }
            }
        }
    }

    private func startResourceMonitor() {
        guard resourceMonitorTask == nil else {
            return
        }

        resourceMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                let snapshot = await ResourceSampler.sample()
                self?.resourceLabel.stringValue = snapshot.displayLine
                self?.resourceLabel.toolTip = snapshot.displayLine

                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func persist(
        transcript: ASRTranscript,
        translation: TranslationResult?,
        window: SpeechWindow
    ) {
        guard let transcriptPersistence else {
            return
        }

        persistedSubtitleCount += 1
        let segment = SubtitleSegment(
            sessionID: transcriptPersistence.sessionID,
            index: persistedSubtitleCount,
            state: translation == nil ? .partial : .translated,
            startTime: window.startTime,
            endTime: window.endTime,
            englishText: transcript.englishText,
            chineseText: translation?.chineseText,
            sourceName: "Google Chrome",
            mode: .live,
            models: ModelSelection(
                asrModel: transcript.modelName,
                translationModel: translation?.modelName
            )
        )

        Task { [transcriptPersistence] in
            do {
                try await transcriptPersistence.append(segment)
            } catch {
                await MainActor.run {
                    self.appendLog("Transcript append failed: \(error)")
                }
            }
        }
    }

    private func persistCloudSubtitle(
        sourceText: String,
        translatedText: String,
        startTime: TimeInterval?,
        endTime: TimeInterval?
    ) {
        guard let transcriptPersistence else {
            return
        }

        persistedSubtitleCount += 1
        let fallbackStart = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let segmentStart = startTime ?? max(0, fallbackStart - 2)
        let segmentEnd = endTime ?? fallbackStart
        let segment = SubtitleSegment(
            sessionID: transcriptPersistence.sessionID,
            index: persistedSubtitleCount,
            state: .translated,
            startTime: segmentStart,
            endTime: max(segmentStart, segmentEnd),
            englishText: sourceText,
            chineseText: translatedText,
            sourceName: "Google Chrome",
            mode: .cloud,
            models: TranslationRuntimeMode.cloudAST.models
        )

        Task { [transcriptPersistence] in
            do {
                try await transcriptPersistence.append(segment)
            } catch {
                await MainActor.run {
                    self.appendLog("Cloud transcript append failed: \(error)")
                }
            }
        }
    }
}

enum AppError: Error, CustomStringConvertible {
    case noDisplayAvailable
    case chromeNotFound
    case shareableContentLoadFailed(String)
    case captureStartFailed(String)
    case captureStopFailed(String)
    case translationFailed(String)

    var description: String {
        switch self {
        case .noDisplayAvailable:
            return "No display is available for ScreenCaptureKit filtering."
        case .chromeNotFound:
            return "Google Chrome is not visible to ScreenCaptureKit. Open Chrome and try again."
        case .shareableContentLoadFailed(let message):
            return "Could not load ScreenCaptureKit shareable content: \(message)"
        case .captureStartFailed(let message):
            return "Could not start capture: \(message)"
        case .captureStopFailed(let message):
            return "Could not stop capture: \(message)"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        }
    }
}

enum ShareableContentLoader {
    static func load() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
        } catch {
            throw AppError.shareableContentLoadFailed(error.localizedDescription)
        }
    }
}

enum AudioProbeEvent: Sendable {
    case firstBuffer(samples: Int, sampleRate: Int, channelCount: Int)
    case speechChanged(isSpeech: Bool, rms: Float, time: TimeInterval)
    case speechWindow(SpeechWindow)
    case stats(buffers: Int, samples: Int, rms: Float, isSpeech: Bool, ringDuration: TimeInterval)
    case stoppedWithError(String)
}

struct ASRTranscript: Sendable {
    var englishText: String
    var modelName: String
    var latencySeconds: TimeInterval
    var segmentIndex: Int
    var revision: Int
}

actor WhisperASREngine {
    private var pipe: WhisperKit?
    nonisolated let modelName: String

    init() {
        self.modelName = ProcessInfo.processInfo.environment["LOCALV_WHISPER_MODEL"]
            ?? "large-v3-v20240930_626MB"
    }

    func prepare() async throws {
        _ = try await loadPipe()
    }

    func transcribe(_ window: SpeechWindow) async throws -> ASRTranscript {
        try Task.checkCancellation()
        let start = Date()
        let pipe = try await loadPipe()
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "en",
            temperature: 0,
            sampleLength: 192,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            wordTimestamps: false,
            noSpeechThreshold: 0.65,
            concurrentWorkerCount: 1
        )

        let results = try await pipe.transcribe(
            audioArray: window.audio.samples,
            decodeOptions: options
        )
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .localvTrimmed

        return ASRTranscript(
            englishText: text,
            modelName: modelName,
            latencySeconds: Date().timeIntervalSince(start),
            segmentIndex: window.segmentIndex,
            revision: window.revision
        )
    }

    private func loadPipe() async throws -> WhisperKit {
        if let pipe {
            return pipe
        }

        let modelFolder = try Self.modelFolder()
        let config = WhisperKitConfig(
            model: modelName,
            downloadBase: modelFolder,
            verbose: false,
            prewarm: true,
            load: true,
            download: true
        )
        let pipe = try await WhisperKit(config)
        self.pipe = pipe
        return pipe
    }

    private static func modelFolder() throws -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let folder = base
            .appendingPathComponent(Brand.storageName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("WhisperKit", isDirectory: true)

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return folder
    }
}

struct TranslationResult: Sendable {
    var chineseText: String
    var modelName: String
}

actor OllamaTranslator {
    nonisolated let preferredModelName = "qwen3.5:4b"
    private var isPrepared = false
    private let models = [
        "qwen3.5:4b",
        "qwen3.5:35b-a3b-coding-nvfp4"
    ]

    func prepare() async {
        guard !isPrepared else {
            return
        }

        _ = try? await translate("hello", model: preferredModelName, maxTokens: 16)
        isPrepared = true
    }

    func translate(_ englishText: String) async throws -> TranslationResult {
        let text = englishText.localvTrimmed
        guard !text.isEmpty else {
            return TranslationResult(chineseText: "", modelName: "none")
        }

        var lastError: Error?
        for model in models {
            do {
                return TranslationResult(
                    chineseText: try await translate(text, model: model, maxTokens: 180),
                    modelName: model
                )
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AppError.translationFailed("No Ollama model responded")
    }

    private func translate(_ text: String, model: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "http://127.0.0.1:11434/api/chat") else {
            throw AppError.translationFailed("Invalid Ollama URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OllamaChatRequest(
            model: model,
            stream: false,
            think: false,
            messages: [
                OllamaMessage(
                    role: "system",
                    content: "Translate English livestream speech into concise Simplified Chinese. Preserve token tickers, project names, numbers, URLs, and product names. Output only Chinese."
                ),
                OllamaMessage(role: "user", content: text)
            ],
            keepAlive: "10m",
            options: OllamaOptions(temperature: 0.1, num_predict: maxTokens)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw AppError.translationFailed("Ollama \(model) HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return decoded.message.content
            .replacingOccurrences(
                of: #"(?s)<think>.*?</think>"#,
                with: "",
                options: .regularExpression
            )
            .localvTrimmed
    }
}

struct OllamaChatRequest: Encodable {
    var model: String
    var stream: Bool
    var think: Bool
    var messages: [OllamaMessage]
    var keepAlive: String
    var options: OllamaOptions

    enum CodingKeys: String, CodingKey {
        case model
        case stream
        case think
        case messages
        case keepAlive = "keep_alive"
        case options
    }
}

struct OllamaMessage: Codable {
    var role: String
    var content: String
}

struct OllamaOptions: Encodable {
    var temperature: Double
    var num_predict: Int
}

struct OllamaChatResponse: Decodable {
    var message: OllamaMessage
}

struct ResourceSnapshot: Sendable {
    var localCPU: Double
    var ollamaCPU: Double
    var localMemoryGB: Double
    var ollamaMemoryGB: Double

    var totalCPU: Double {
        localCPU + ollamaCPU
    }

    var totalMemoryGB: Double {
        localMemoryGB + ollamaMemoryGB
    }

    var tier: String {
        if totalCPU >= 120 || totalMemoryGB >= 12 {
            return "高"
        }

        if totalCPU >= 30 || totalMemoryGB >= 6 {
            return "中"
        }

        return "低"
    }

    var displayLine: String {
        "\(tier) · CPU \(Int(totalCPU.rounded()))% · 内存 \(String(format: "%.1f", totalMemoryGB))GB"
    }
}

enum ResourceSampler {
    static func sample() async -> ResourceSnapshot {
        await Task.detached(priority: .utility) {
            sampleSync()
        }.value
    }

    private static func sampleSync() -> ResourceSnapshot {
        let rows = processRows()

        let localCPU = currentTaskCPUPercent()
        let localMemoryGB = currentTaskResidentMemoryGB()
        var ollamaCPU = 0.0
        var ollamaRSS = 0.0

        for row in rows {
            if row.command.localizedCaseInsensitiveContains("ollama") {
                ollamaCPU += row.cpu
                ollamaRSS += row.rssKB
            }
        }

        return ResourceSnapshot(
            localCPU: localCPU,
            ollamaCPU: ollamaCPU,
            localMemoryGB: localMemoryGB,
            ollamaMemoryGB: ollamaRSS / 1_048_576
        )
    }

    private static func currentTaskResidentMemoryGB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    rebound,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return Double(info.resident_size) / 1_073_741_824
    }

    private static func currentTaskCPUPercent() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threadList else {
            return 0
        }

        defer {
            let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), size)
        }

        var total = 0.0
        for index in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                    thread_info(
                        threadList[index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        rebound,
                        &count
                    )
                }
            }

            if infoResult == KERN_SUCCESS,
               info.flags & TH_FLAGS_IDLE == 0 {
                total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }

        return total
    }

    private static func processRows() -> [ProcessResourceRow] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm=,%cpu=,rss="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output
            .split(separator: "\n")
            .compactMap { ProcessResourceRow(String($0)) }
    }
}

struct ProcessResourceRow: Sendable {
    var pid: Int32
    var command: String
    var cpu: Double
    var rssKB: Double

    init?(_ line: String) {
        let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard columns.count >= 4,
              let pid = Int32(columns[0]),
              let cpu = Double(columns[columns.count - 2]),
              let rssKB = Double(columns[columns.count - 1])
        else {
            return nil
        }

        self.pid = pid
        self.command = columns[1..<(columns.count - 2)].joined(separator: " ")
        self.cpu = cpu
        self.rssKB = rssKB
    }
}

actor TranscriptPersistence {
    nonisolated let sessionID: UUID
    nonisolated let markdownURL: URL
    nonisolated let jsonlURL: URL
    nonisolated let manifestURL: URL

    private var manifest: SessionManifest
    private let writer = TranscriptWriter()

    private init(
        manifest: SessionManifest,
        markdownURL: URL,
        jsonlURL: URL,
        manifestURL: URL
    ) {
        self.sessionID = manifest.id
        self.manifest = manifest
        self.markdownURL = markdownURL
        self.jsonlURL = jsonlURL
        self.manifestURL = manifestURL
    }

    static func start(sourceName: String, mode: LocalVMode = .live, models: ModelSelection) throws -> TranscriptPersistence {
        let manifest = SessionManifest(
            sourceKind: .chromeApp,
            sourceName: sourceName,
            title: "Chrome Live",
            mode: mode,
            models: models
        )
        let directory = try sessionDirectory(startedAt: manifest.startedAt)
        let baseName = "\(manifest.safeBaseFilename())_\(manifest.id.uuidString.prefix(8))"
        let markdownURL = directory.appendingPathComponent("\(baseName).md")
        let jsonlURL = directory.appendingPathComponent("\(baseName).jsonl")
        let manifestURL = directory.appendingPathComponent("\(baseName).manifest.json")
        let persistence = TranscriptPersistence(
            manifest: manifest,
            markdownURL: markdownURL,
            jsonlURL: jsonlURL,
            manifestURL: manifestURL
        )

        let writer = TranscriptWriter()
        try Self.writeManifest(manifest, to: manifestURL)
        try writer.markdownHeader(for: manifest).write(
            to: markdownURL,
            atomically: true,
            encoding: .utf8
        )
        _ = FileManager.default.createFile(
            atPath: jsonlURL.path,
            contents: nil
        )
        return persistence
    }

    func append(_ segment: SubtitleSegment) throws {
        try append(try writer.jsonLine(for: segment), to: jsonlURL)
        try append(writer.markdownBlock(for: segment), to: markdownURL)
    }

    func finish() throws {
        manifest.endedAt = Date()
        try writeManifest()
    }

    private func writeManifest() throws {
        try Self.writeManifest(manifest, to: manifestURL)
    }

    private static func writeManifest(_ manifest: SessionManifest, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    private func append(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else {
            throw TranscriptWriter.TranscriptError.invalidUTF8
        }

        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        handle.write(data)
    }

    private static func sessionDirectory(startedAt: Date) throws -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let directory = base
            .appendingPathComponent(Brand.storageName, isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent(formatter.string(from: startedAt), isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

final class AudioProbe: NSObject, SCStreamOutput, SCStreamDelegate {
    private(set) var audioBufferCount = 0
    private(set) var audioSampleCount = 0
    private(set) var extractedSampleCount = 0

    private var segmenter: StreamingAudioSegmenter
    private let audioSink: (@Sendable (LocalVCore.AudioChunk) -> Void)?
    private let emit: @Sendable (AudioProbeEvent) -> Void

    init(
        configuration: AudioSegmenterConfiguration = AudioSegmenterConfiguration(),
        audioSink: (@Sendable (LocalVCore.AudioChunk) -> Void)? = nil,
        emit: @escaping @Sendable (AudioProbeEvent) -> Void
    ) {
        self.segmenter = StreamingAudioSegmenter(configuration: configuration)
        self.audioSink = audioSink
        self.emit = emit
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else {
            return
        }

        let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let startTime = TimeInterval(audioSampleCount) / TimeInterval(segmenter.configuration.sampleRate)
        audioBufferCount += 1
        audioSampleCount += sampleCount

        guard let chunk = AudioSampleExtractor.chunk(from: sampleBuffer, startTime: startTime) else {
            return
        }

        extractedSampleCount += chunk.frameCount
        audioSink?(chunk)

        let previousSpeech = segmenter.isSpeech
        let windows = segmenter.append(chunk)
        let decision = segmenter.lastDecision

        if audioBufferCount == 1 {
            emit(.firstBuffer(samples: chunk.samples.count, sampleRate: chunk.sampleRate, channelCount: chunk.channelCount))
        }

        if segmenter.isSpeech != previousSpeech {
            emit(.speechChanged(isSpeech: segmenter.isSpeech, rms: decision.rms, time: segmenter.ringBuffer.endTime))
        }

        for window in windows {
            emit(.speechWindow(window))
        }

        if audioBufferCount % 50 == 0 {
            emit(
                .stats(
                    buffers: audioBufferCount,
                    samples: audioSampleCount,
                    rms: decision.rms,
                    isSpeech: segmenter.isSpeech,
                    ringDuration: segmenter.ringBuffer.duration
                )
            )
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        emit(.stoppedWithError(error.localizedDescription))
    }
}

enum AudioSampleExtractor {
    static func chunk(from sampleBuffer: CMSampleBuffer, startTime: TimeInterval) -> LocalVCore.AudioChunk? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescriptionPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            return nil
        }

        let streamDescription = streamDescriptionPointer.pointee
        guard streamDescription.mFormatID == kAudioFormatLinearPCM else {
            return nil
        }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
        )

        let status = withUnsafeMutablePointer(to: &audioBufferList) { listPointer in
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: listPointer,
                bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: &blockBuffer
            )
        }

        guard status == noErr,
              let data = audioBufferList.mBuffers.mData
        else {
            return nil
        }

        let channelCount = max(1, Int(streamDescription.mChannelsPerFrame))
        let sampleRate = Int(streamDescription.mSampleRate.rounded())
        let bytesPerSample = max(1, Int(streamDescription.mBitsPerChannel / 8))
        let sampleCount = Int(audioBufferList.mBuffers.mDataByteSize) / bytesPerSample
        let flags = streamDescription.mFormatFlags

        let samples: [Float]
        if flags & kAudioFormatFlagIsFloat != 0 && streamDescription.mBitsPerChannel == 32 {
            let pointer = data.bindMemory(to: Float.self, capacity: sampleCount)
            samples = Array(UnsafeBufferPointer(start: pointer, count: sampleCount))
        } else if flags & kAudioFormatFlagIsSignedInteger != 0 && streamDescription.mBitsPerChannel == 16 {
            let pointer = data.bindMemory(to: Int16.self, capacity: sampleCount)
            samples = UnsafeBufferPointer(start: pointer, count: sampleCount).map { Float($0) / Float(Int16.max) }
        } else if flags & kAudioFormatFlagIsSignedInteger != 0 && streamDescription.mBitsPerChannel == 32 {
            let pointer = data.bindMemory(to: Int32.self, capacity: sampleCount)
            samples = UnsafeBufferPointer(start: pointer, count: sampleCount).map { Float($0) / Float(Int32.max) }
        } else {
            return nil
        }

        return LocalVCore.AudioChunk(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: channelCount,
            startTime: startTime
        )
    }
}

extension SCStream {
    func startCaptureAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startCapture { error in
                if let error {
                    continuation.resume(throwing: AppError.captureStartFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func stopCaptureAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stopCapture { error in
                if let error {
                    continuation.resume(throwing: AppError.captureStopFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension String {
    fileprivate var localvTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
