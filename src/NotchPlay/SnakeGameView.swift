import SwiftUI

// MARK: - Types

enum SnakeDirection {
    case up, down, left, right

    var opposite: SnakeDirection {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    var delta: (dx: Int, dy: Int) {
        switch self {
        case .up:    (0, -1)
        case .down:  (0,  1)
        case .left:  (-1, 0)
        case .right: ( 1, 0)
        }
    }
}

struct SnakeGridPos: Equatable, Hashable {
    var x: Int
    var y: Int
}

// MARK: - Engine

final class SnakeGameEngine {

    // Grid
    var cellSize: CGFloat = 8
    var gridW: Int = 0
    var gridH: Int = 0

    // Snake
    var body: [SnakeGridPos] = []
    var direction: SnakeDirection = .right
    var nextDirection: SnakeDirection = .right
    var growing = false

    // Apple
    var apple: SnakeGridPos = SnakeGridPos(x: 0, y: 0)

    // Timing
    let moveInterval: CGFloat = 0.12
    var moveTimer: CGFloat = 0
    var lastUpdate: Date?

    // Interpolation (0…1 progress between grid steps)
    var stepProgress: CGFloat = 0

    // State
    var score: Int = 0
    var gameStarted = false
    var isGameOver = false
    var canvasSize: CGSize = .zero

    // MARK: - Setup

    func reset(size: CGSize) {
        canvasSize = size
        gridW = Int(size.width / cellSize)
        gridH = Int(size.height / cellSize)

        let midX = gridW / 2
        let midY = gridH / 2
        body = [
            SnakeGridPos(x: midX, y: midY),
            SnakeGridPos(x: midX - 1, y: midY),
            SnakeGridPos(x: midX - 2, y: midY)
        ]
        direction = .right
        nextDirection = .right
        growing = false
        score = 0
        isGameOver = false
        gameStarted = false
        moveTimer = 0
        stepProgress = 0
        lastUpdate = nil
        spawnApple()
    }

    private func spawnApple() {
        let occupied = Set(body)
        var candidates: [SnakeGridPos] = []
        for x in 0..<gridW {
            for y in 0..<gridH {
                let p = SnakeGridPos(x: x, y: y)
                if !occupied.contains(p) {
                    candidates.append(p)
                }
            }
        }
        if let pos = candidates.randomElement() {
            apple = pos
        }
    }

    // MARK: - Input

    func setDirection(_ dir: SnakeDirection) {
        if isGameOver {
            reset(size: canvasSize)
            return
        }
        if !gameStarted {
            gameStarted = true
        }
        // Prevent reversing into self
        if dir.opposite != direction {
            nextDirection = dir
            // Immediately step so turn feels instant
            if moveTimer > 0.02 {
                moveTimer = 0
                stepProgress = 0
                step()
            }
        }
    }

    // MARK: - Update

    func update(date: Date, size: CGSize) {
        if canvasSize != size || body.isEmpty {
            reset(size: size)
        }

        guard let last = lastUpdate else {
            lastUpdate = date
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 30.0))
        lastUpdate = date

        guard gameStarted, !isGameOver else {
            stepProgress = 0
            return
        }

        moveTimer += dt
        stepProgress = min(moveTimer / moveInterval, 1.0)

        if moveTimer >= moveInterval {
            moveTimer -= moveInterval
            stepProgress = 0
            step()
        }
    }

    private func step() {
        direction = nextDirection

        guard let head = body.first else { return }
        let d = direction.delta
        let newHead = SnakeGridPos(x: head.x + d.dx, y: head.y + d.dy)

        // Wall collision
        if newHead.x < 0 || newHead.x >= gridW || newHead.y < 0 || newHead.y >= gridH {
            isGameOver = true
            return
        }

        // Self collision (check against body excluding last tail if not growing)
        let checkBody = growing ? body : Array(body.dropLast())
        if checkBody.contains(newHead) {
            isGameOver = true
            return
        }

        body.insert(newHead, at: 0)

        if newHead == apple {
            score += 1
            growing = true
            spawnApple()
        }

        if growing {
            growing = false
            // Don't remove tail - snake grew
        } else {
            body.removeLast()
        }
    }

    // MARK: - Drawing

    func draw(context: inout GraphicsContext, size: CGSize) {
        let cs = cellSize

        // Subtle grid
        let gridColor = Color.white.opacity(0.03)
        for x in 0...gridW {
            let px = CGFloat(x) * cs
            context.fill(Path(CGRect(x: px, y: 0, width: 0.5, height: size.height)), with: .color(gridColor))
        }
        for y in 0...gridH {
            let py = CGFloat(y) * cs
            context.fill(Path(CGRect(x: 0, y: py, width: size.width, height: 0.5)), with: .color(gridColor))
        }

        // Apple
        let appleRect = CGRect(x: CGFloat(apple.x) * cs + 1, y: CGFloat(apple.y) * cs + 1, width: cs - 2, height: cs - 2)
        context.fill(Path(ellipseIn: appleRect), with: .color(.red))

        // Snake
        guard !body.isEmpty else { return }

        let snakeColor = Color.green
        let headColor = Color(hue: 0.33, saturation: 0.8, brightness: 0.9)
        let t = gameStarted && !isGameOver ? stepProgress : 0

        for (i, segment) in body.enumerated() {
            var drawX = CGFloat(segment.x) * cs
            var drawY = CGFloat(segment.y) * cs

            if i == 0 {
                // Head: interpolate toward next grid cell
                let d = direction.delta
                drawX += CGFloat(d.dx) * cs * t
                drawY += CGFloat(d.dy) * cs * t
            } else {
                // Body segments: interpolate toward the segment ahead
                let ahead = body[i - 1]
                let dx = CGFloat(ahead.x - segment.x)
                let dy = CGFloat(ahead.y - segment.y)
                drawX += dx * cs * t
                drawY += dy * cs * t
            }

            let inset: CGFloat = i == 0 ? 0.5 : 1
            let rect = CGRect(x: drawX + inset, y: drawY + inset, width: cs - inset * 2, height: cs - inset * 2)
            let color = i == 0 ? headColor : snakeColor.opacity(1.0 - Double(i) * 0.02)
            context.fill(Path(rect), with: .color(color))
        }

        // Score
        let scoreText = Text(String(score))
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
        context.draw(scoreText, at: CGPoint(x: size.width - 16, y: 10))

        // Game over
        if isGameOver {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.5))
            )
            context.draw(
                Text("GAME OVER").font(.system(size: 16, weight: .bold)).foregroundColor(.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 10)
            )
            context.draw(
                Text("Press any arrow to restart").font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 8)
            )
        }

        // Start prompt
        if !gameStarted && !isGameOver {
            context.draw(
                Text("Arrow keys to start").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
    }
}

// MARK: - View

struct SnakeGameView: View {
    @State private var engine = SnakeGameEngine()
    @State private var keyMonitor: Any?

    var body: some View {
        TimelineView(.animation(paused: false)) { timeline in
            Canvas { context, size in
                engine.update(date: timeline.date, size: size)
                engine.draw(context: &context, size: size)
            }
        }
        .onAppear { startInput() }
        .onDisappear { stopInput() }
    }

    private func startInput() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 126, 13: engine.setDirection(.up);    return nil  // Up arrow, W
            case 125, 1:  engine.setDirection(.down);  return nil  // Down arrow, S
            case 123, 0:  engine.setDirection(.left);  return nil  // Left arrow, A
            case 124, 2:  engine.setDirection(.right); return nil  // Right arrow, D
            default: return event
            }
        }
    }

    private func stopInput() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
