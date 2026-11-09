import AppKit

@MainActor
func descendants(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap { descendants($0) }
}

@MainActor
final class ProfileDelegate: NSObject, NSApplicationDelegate {
    private var menu: MenuBarController!
    private let originalCollapsed = Settings.isCollapsed

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu = MenuBarController()
        Task { await run() }
    }

    func check(_ condition: Bool, _ message: String) {
        guard condition else {
            print("FAIL: \(message); divider=\(String(describing: menu.dividerFrame)); arrow=\(String(describing: menu.arrowFrame)); state=\(Mirror(reflecting: menu!).children.map { "\($0.label ?? "?")=\($0.value)" })")
            fflush(stdout)
            exit(1)
        }
    }

    func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    func snapshot(_ stage: String) {
        print("\nSTAGE: \(stage), divider=\(menu.dividerFrame?.width ?? -1), screens=\(NSScreen.screens.map { $0.frame.width }), AX=\(Permissions.hasAccessibility)")
        for (tool, args) in [("/usr/bin/footprint", [String(getpid())]),
                             ("/usr/bin/top", ["-l", "1", "-pid", String(getpid()), "-stats", "pid,mem,ports,cpu,threads"])] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try! process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            print(String(decoding: data, as: UTF8.self))
        }
        fflush(stdout)
    }

    func waitForScan(_ controller: SettingsWindowController) async {
        for _ in 0..<100 {
            let views = descendants(controller.window!.contentView!)
            let labels = views.compactMap { ($0 as? NSTextField)?.stringValue }
            if !Permissions.hasAccessibility || labels.contains(where: { $0.first?.isNumber == true && $0.hasSuffix(" items") }) { return }
            await pause(0.1)
        }
        check(false, "Settings scan did not finish within 10 seconds")
    }

    func run() async {
        await pause(1)
        menu.collapse()
        await pause(1)
        snapshot("launch")
        if !Permissions.hasAccessibility { print("NOTICE: Accessibility unavailable; scans and moves are not exercised") }
        let toggleCycles = ProcessInfo.processInfo.environment["TUCK_PROFILE_QUICK"] == "1" ? 1 : 100
        for cycle in 1...toggleCycles {
            menu.expand(autoRehide: false)
            await pause(0.1)
            menu.collapse()
            await pause(0.1)
            check(menu.isCollapsed, "Collapse failed")
            if cycle == 50 || cycle == 100 {
                await pause(1)
                snapshot("toggle \(cycle)")
            }
        }
        for cycle in 1...30 {
            var controller: SettingsWindowController? = SettingsWindowController(menuBar: menu, onClose: {})
            controller!.show()
            await waitForScan(controller!)
            if cycle == 1 { print("First Settings scan finished"); fflush(stdout) }
            controller!.perform(NSSelectorFromString("refreshClicked"))
            await waitForScan(controller!)
            if cycle == 1 { print("First Settings refresh finished"); fflush(stdout) }
            weak let weakController = controller
            controller!.close()
            controller = nil
            await pause(0.3)
            if weakController != nil {
                await pause(2)
                check(weakController == nil, "Closed Settings controller retained")
            }
            check(menu.isCollapsed, "Settings hold leaked")
            if cycle == 15 || cycle == 30 { snapshot("settings \(cycle)") }
        }
        if CommandLine.arguments.contains("--cancellation") {
            for cycle in 0..<10 {
                var controller: SettingsWindowController? = SettingsWindowController(menuBar: menu, onClose: {})
                controller!.show()
                for _ in 0..<10 { controller!.perform(NSSelectorFromString("refreshClicked")) }
                // Alternate cancellation during the layout delay and during Accessibility work.
                if cycle != 0 { await pause(cycle.isMultiple(of: 2) ? 0.25 : 0.01) }
                weak let weakController = controller
                controller!.close()
                controller = nil
                for _ in 0..<100 {
                    if weakController == nil { break }
                    await pause(0.1)
                }
                check(weakController == nil, "Cancelled Settings controller retained")
                check(menu.isCollapsed, "Cancelled Settings hold leaked")
            }
            snapshot("cancelled settings 10")
        }
        await pause(5)
        snapshot("settled")
        await pause(10)
        snapshot("idle 10 seconds")
        if !originalCollapsed { menu.expand(autoRehide: false) }
        Settings.isCollapsed = originalCollapsed
        print("PASS: \(toggleCycles) toggles, 30 Settings open/refresh/close cycles")
        fflush(stdout)
        NSApp.terminate(nil)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = ProfileDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
