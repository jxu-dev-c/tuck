import CoreGraphics
import Foundation

/// Moves a real menu bar item by synthesizing the same ⌘-drag a user would do.
enum ItemMover {
    enum Placement {
        case leftOf(CGRect)
        case rightOf(CGRect)
    }

    static func move(_ item: MenuBarItem, to placement: Placement) async {
        let start = CGPoint(x: item.frame.midX, y: item.frame.midY)
        // Dropping just inside the target's edge lands on the requested side whichever direction
        // we came from: macOS swaps items once the cursor crosses an item's midpoint.
        let endX = switch placement {
        case .leftOf(let rect): rect.minX + 1
        case .rightOf(let rect): rect.maxX - 1
        }
        let end = CGPoint(x: endX, y: start.y)
        await Task.detached(priority: .userInitiated) { performDrag(from: start, to: end) }.value
    }

    private static func performDrag(from start: CGPoint, to end: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let originalCursor = CGEvent(source: nil)?.location

        func post(_ type: CGEventType, at point: CGPoint, command: Bool = true) {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return }
            event.flags = command ? .maskCommand : []
            event.post(tap: .cghidEventTap)
        }

        post(.mouseMoved, at: start)
        usleep(30_000)
        post(.leftMouseDown, at: start)
        usleep(60_000)
        let steps = 10
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            post(.leftMouseDragged, at: CGPoint(x: start.x + (end.x - start.x) * t, y: start.y))
            usleep(15_000)
        }
        usleep(60_000)
        post(.leftMouseUp, at: end)
        usleep(30_000)

        if let originalCursor {
            CGWarpMouseCursorPosition(originalCursor)
            post(.mouseMoved, at: originalCursor, command: false)
        }
    }
}
