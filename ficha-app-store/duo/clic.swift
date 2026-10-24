// clic.swift — clic o arrastre de ratón en puntos de la pantalla del Mac (CGEvent). Lo compila duo/comun.sh.
import CoreGraphics
import Foundation
// uso: click x y [drag x2 y2]  (coordenadas en puntos de pantalla)
let a = CommandLine.arguments
func post(_ t: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
let p = CGPoint(x: Double(a[1])!, y: Double(a[2])!)
if a.count >= 6 && a[3] == "drag" {
    let q = CGPoint(x: Double(a[4])!, y: Double(a[5])!)
    post(.mouseMoved, p); usleep(100_000)
    post(.leftMouseDown, p); usleep(150_000)
    let steps = 30
    for i in 1...steps {
        let t = Double(i)/Double(steps)
        post(.leftMouseDragged, CGPoint(x: p.x + (q.x-p.x)*t, y: p.y + (q.y-p.y)*t)); usleep(20_000)
    }
    usleep(150_000); post(.leftMouseUp, q)
} else {
    post(.mouseMoved, p); usleep(80_000)
    post(.leftMouseDown, p); usleep(UInt32(ProcessInfo.processInfo.environment["HOLD_MS"].flatMap { UInt32($0) } ?? 80) * 1000); post(.leftMouseUp, p)
}
