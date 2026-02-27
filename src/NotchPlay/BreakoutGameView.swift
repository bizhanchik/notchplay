import SwiftUI

// MARK: - Data Types

struct BreakoutBrick {
    var col: Int
    var row: Int
    var alive: Bool
    var hue: CGFloat
    var destroyTime: CGFloat? // nil = alive, set when hit for fade anim
}

// MARK: - Engine

final class BreakoutGameEngine {

    var canvasSize: CGSize = CGSize(width: 420, height: 180)
    var lastUpdate: Date?
    var time: CGFloat = 0

    // Ball
    var ballPos: CGPoint = .zero
    var ballVel: CGPoint = .zero
    let ballRadius: CGFloat = 3
    let baseBallSpeed: CGFloat = 155

    // Paddle
    var paddleX: CGFloat = 0 // center X
    let paddleWidth: CGFloat = 40
    let paddleHeight: CGFloat = 5
    let paddleBottomMargin: CGFloat = 8
    var mouseX: CGFloat? = nil

    var paddleY: CGFloat {
        canvasSize.height - paddleBottomMargin - paddleHeight / 2
    }

    // Bricks
    var bricks: [BreakoutBrick] = []
    let brickRows = 6
    let brickCols = 14
    let brickHeight: CGFloat = 6
    let brickSpacing: CGFloat = 1.5
    let brickTopMargin: CGFloat = 4

    // State
    var gameStarted = false
    var isGameOver = false
    var isVictory = false
    var score = 0
    var lives = 3

    // MARK: - Setup

    func reset(size: CGSize) {
        canvasSize = size
        lastUpdate = nil
        time = 0
        gameStarted = false
        isGameOver = false
        isVictory = false
        score = 0
        lives = 3
        paddleX = size.width / 2
        mouseX = nil

        setupBricks(size: size)
        resetBall(size: size)
    }

    private func setupBricks(size: CGSize) {
        bricks = []
        for row in 0..<brickRows {
            let hue = CGFloat(row) / CGFloat(brickRows) // rainbow: 0=red ... 0.83=purple
            for col in 0..<brickCols {
                bricks.append(BreakoutBrick(col: col, row: row, alive: true, hue: hue, destroyTime: nil))
            }
        }
    }

    private func resetBall(size: CGSize) {
        ballPos = CGPoint(x: size.width / 2, y: paddleY - 20)
        let angle = CGFloat.random(in: -0.5...0.5)
        ballVel = CGPoint(
            x: baseBallSpeed * sin(angle),
            y: -baseBallSpeed * cos(angle)
        )
    }

    func brickRect(col: Int, row: Int, size: CGSize) -> CGRect {
        let totalSpacing = brickSpacing * CGFloat(brickCols - 1)
        let brickWidth = (size.width - totalSpacing) / CGFloat(brickCols)
        let x = CGFloat(col) * (brickWidth + brickSpacing)
        let y = brickTopMargin + CGFloat(row) * (brickHeight + brickSpacing)
        return CGRect(x: x, y: y, width: brickWidth, height: brickHeight)
    }

    // MARK: - Start

    func start() {
        if isGameOver || isVictory {
            reset(size: canvasSize)
            return
        }
        if !gameStarted {
            gameStarted = true
        }
    }

    // MARK: - Update

    func update(date: Date, size: CGSize) {
        canvasSize = size

        guard let last = lastUpdate else {
            lastUpdate = date
            if bricks.isEmpty { reset(size: size) }
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 30.0))
        lastUpdate = date
        time += dt

        // Paddle follows mouse
        if let mx = mouseX {
            let half = paddleWidth / 2
            paddleX = min(max(mx, half), size.width - half)
        }

        guard gameStarted, !isGameOver, !isVictory else { return }

        // Ball movement
        ballPos.x += ballVel.x * dt
        ballPos.y += ballVel.y * dt

        // Wall bounces
        if ballPos.x - ballRadius <= 0 {
            ballPos.x = ballRadius
            ballVel.x = abs(ballVel.x)
        } else if ballPos.x + ballRadius >= size.width {
            ballPos.x = size.width - ballRadius
            ballVel.x = -abs(ballVel.x)
        }
        if ballPos.y - ballRadius <= 0 {
            ballPos.y = ballRadius
            ballVel.y = abs(ballVel.y)
        }

        // Paddle collision
        let pTop = paddleY - paddleHeight / 2
        let pLeft = paddleX - paddleWidth / 2
        let pRight = paddleX + paddleWidth / 2

        if ballVel.y > 0,
           ballPos.y + ballRadius >= pTop,
           ballPos.y + ballRadius <= pTop + paddleHeight + 4,
           ballPos.x >= pLeft - ballRadius,
           ballPos.x <= pRight + ballRadius {
            ballPos.y = pTop - ballRadius
            // Angle based on hit offset: center=straight up, edge=angled
            let hitOffset = (ballPos.x - paddleX) / (paddleWidth / 2) // -1..1
            let maxAngle: CGFloat = 1.1 // ~63 degrees
            let angle = hitOffset * maxAngle
            let speed = sqrt(ballVel.x * ballVel.x + ballVel.y * ballVel.y)
            ballVel = CGPoint(
                x: speed * sin(angle),
                y: -speed * cos(angle)
            )
        }

        // Ball fell below
        if ballPos.y - ballRadius > size.height {
            lives -= 1
            if lives <= 0 {
                isGameOver = true
            } else {
                resetBall(size: size)
            }
        }

        // Brick collisions
        for i in bricks.indices {
            guard bricks[i].alive else { continue }
            let rect = brickRect(col: bricks[i].col, row: bricks[i].row, size: size)

            // Expanded rect for ball radius
            let expanded = rect.insetBy(dx: -ballRadius, dy: -ballRadius)
            guard expanded.contains(ballPos) else { continue }

            // Destroy brick
            bricks[i].alive = false
            bricks[i].destroyTime = time
            score += 1

            // Reflect ball
            let cx = rect.midX
            let cy = rect.midY
            let dx = ballPos.x - cx
            let dy = ballPos.y - cy
            let scaleX = abs(dx) / (rect.width / 2 + ballRadius)
            let scaleY = abs(dy) / (rect.height / 2 + ballRadius)

            if scaleX > scaleY {
                ballVel.x = -ballVel.x
            } else {
                ballVel.y = -ballVel.y
            }

            break // one brick per frame to avoid multi-hit glitches
        }

        // Victory check
        if bricks.allSatisfy({ !$0.alive }) {
            isVictory = true
        }
    }

    // MARK: - Drawing

    func draw(context: inout GraphicsContext, size: CGSize) {
        drawBackground(context: &context, size: size)
        drawBricks(context: &context, size: size)
        drawPaddle(context: &context, size: size)
        drawBall(context: &context, size: size)
        drawUI(context: &context, size: size)
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        let top = Color(hue: 0.58, saturation: 0.4, brightness: 0.12)
        let bottom = Color(hue: 0.6, saturation: 0.5, brightness: 0.08)
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawBricks(context: inout GraphicsContext, size: CGSize) {
        for brick in bricks {
            let rect = brickRect(col: brick.col, row: brick.row, size: size)

            if brick.alive {
                let color = Color(hue: brick.hue, saturation: 0.85, brightness: 0.9)
                let highlight = Color(hue: brick.hue, saturation: 0.7, brightness: 1.0)

                // Main brick body
                let rrect = RoundedRectangle(cornerRadius: 1.5)
                    .path(in: rect)
                context.fill(rrect, with: .color(color))

                // Subtle top highlight
                let highlightRect = CGRect(x: rect.minX + 1, y: rect.minY, width: rect.width - 2, height: 1.5)
                context.fill(Path(highlightRect), with: .color(highlight.opacity(0.4)))

            } else if let dt = brick.destroyTime {
                // Fade-out animation (0.2s)
                let elapsed = time - dt
                let fadeDuration: CGFloat = 0.2
                if elapsed < fadeDuration {
                    let alpha = 1.0 - elapsed / fadeDuration
                    let scale = 1.0 + elapsed / fadeDuration * 0.3
                    let color = Color(hue: brick.hue, saturation: 0.85, brightness: 0.9).opacity(alpha)

                    let cx = rect.midX
                    let cy = rect.midY
                    let scaledRect = CGRect(
                        x: cx - rect.width * scale / 2,
                        y: cy - rect.height * scale / 2,
                        width: rect.width * scale,
                        height: rect.height * scale
                    )
                    let rrect = RoundedRectangle(cornerRadius: 1.5).path(in: scaledRect)
                    context.fill(rrect, with: .color(color))
                }
            }
        }
    }

    private func drawPaddle(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(
            x: paddleX - paddleWidth / 2,
            y: paddleY - paddleHeight / 2,
            width: paddleWidth,
            height: paddleHeight
        )
        let rrect = RoundedRectangle(cornerRadius: 2).path(in: rect)
        context.fill(rrect, with: .color(.white.opacity(0.85)))

        // Subtle segmented look
        let segCount = 5
        let segW = paddleWidth / CGFloat(segCount)
        for i in 1..<segCount {
            let x = rect.minX + CGFloat(i) * segW
            context.fill(
                Path(CGRect(x: x, y: rect.minY, width: 0.5, height: paddleHeight)),
                with: .color(.black.opacity(0.2))
            )
        }
    }

    private func drawBall(context: inout GraphicsContext, size: CGSize) {
        guard !isGameOver else { return }
        let r = ballRadius
        let rect = CGRect(x: ballPos.x - r, y: ballPos.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.white))
    }

    private func drawUI(context: inout GraphicsContext, size: CGSize) {
        // Lives
        let livesText = Text(String(repeating: "●", count: lives))
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white.opacity(0.5))
        context.draw(livesText, at: CGPoint(x: 16, y: size.height - 6))

        // Score
        let scoreText = Text(String(score))
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
        context.draw(scoreText, at: CGPoint(x: size.width - 16, y: size.height - 6))

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
                Text("Click to restart").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            )
        }

        if isVictory {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.4))
            )
            context.draw(
                Text("YOU WIN!").font(.system(size: 16, weight: .bold)).foregroundColor(.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 10)
            )
            context.draw(
                Text("Click to play again").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            )
        }

        if !gameStarted && !isGameOver && !isVictory {
            context.draw(
                Text("Click to start").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
    }
}

// MARK: - View

struct BreakoutGameView: View {
    @State private var engine = BreakoutGameEngine()
    @State private var moveMonitor: Any?
    @State private var clickMonitor: Any?

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
        moveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            if event.window != nil {
                let windowX = event.locationInWindow.x
                // Account for horizontal safe area padding
                let canvasX = windowX - NotchLayout.safeAreaHorizontal
                engine.mouseX = canvasX
            }
            return event
        }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            engine.start()
            // Also update paddle position on click
            if event.window != nil {
                let canvasX = event.locationInWindow.x - NotchLayout.safeAreaHorizontal
                engine.mouseX = canvasX
            }
            return event
        }
    }

    private func stopInput() {
        if let m = moveMonitor { NSEvent.removeMonitor(m); moveMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }
}
