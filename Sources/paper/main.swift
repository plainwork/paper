import Cocoa
import Carbon.HIToolbox

final class EditorViewController: NSViewController {
    private let textView = NSTextView(frame: .zero)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)
    private var quitTrackingArea: NSTrackingArea?

    override func loadView() {
        let containerSize = NSSize(width: 360, height: 260)
        let container = NSView(frame: NSRect(origin: .zero, size: containerSize))

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 14, height: 12)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        let separator = NSBox()
        separator.boxType = .separator

        quitButton.attributedTitle = makeQuitTitle(isHovered: false)
        quitButton.isBordered = false
        quitButton.target = self
        quitButton.action = #selector(quitApp)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scrollView)
        container.addSubview(separator)
        container.addSubview(quitButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: quitButton.topAnchor, constant: -6),

            quitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            quitButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])

        view = container
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let trackingArea = quitTrackingArea {
            quitButton.removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        quitButton.addTrackingArea(trackingArea)
        quitTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        quitButton.attributedTitle = makeQuitTitle(isHovered: true)
    }

    override func mouseExited(with event: NSEvent) {
        quitButton.attributedTitle = makeQuitTitle(isHovered: false)
    }

    func focusEditor() {
        view.window?.makeFirstResponder(textView)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func makeQuitTitle(isHovered: Bool) -> NSAttributedString {
        let mainColor = isHovered ? NSColor.labelColor : NSColor.secondaryLabelColor
        let hintColor = isHovered ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor

        let quitTitle = NSMutableAttributedString(
            string: "Quit",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: mainColor
            ]
        )
        let shortcutTitle = NSAttributedString(
            string: "  ⌘Q",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: hintColor
            ]
        )
        quitTitle.append(shortcutTitle)
        return quitTitle
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let editorController = EditorViewController()
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    private var hotKeyHandlerUPP: EventHandlerUPP?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(named: "MenuBarTemplate") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        } else {
            item.button?.title = "paper"
        }
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item

        popover.contentViewController = editorController
        popover.behavior = .transient

        registerGlobalHotKey()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        editorController.focusEditor()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Paper")
        let quitItem = NSMenuItem(title: "Quit Paper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func registerGlobalHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x50415052), id: 1) // 'PAPR'
        let modifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey)
        let keyCode: UInt32 = 35 // P key

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async {
                AppDelegate.shared?.togglePopover()
            }
            return noErr
        }
        hotKeyHandlerUPP = handler
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &hotKeyHandlerRef)
    }

    static weak var shared: AppDelegate?
}

let app = NSApplication.shared
let delegate = AppDelegate()
AppDelegate.shared = delegate
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
