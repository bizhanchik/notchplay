import SwiftUI

// MARK: - Game Engine

final class PongGameEngine {

    // Field
    var canvasSize: CGSize = CGSize(width: 420, height: 180)

    // Ball
    var ballPos: CGPoint = .zero
    var ballVel: CGPoint = .zero
    let ballSize: CGFloat = 6

    // Paddles
    var playerY: CGFloat = 0       // center Y
    var aiY: CGFloat = 0           // center Y
    let paddleWidth: CGFloat = 4
    let paddleHeight: CGFloat = 28
    let paddleInset: CGFloat = 12  // distance from edge

    // AI
    let aiMaxSpeed: CGFloat = 130
    let aiReaction: CGFloat = 0.85 // how close to perfect (0–1)

    // Scores
    var playerScore: Int = 0
    var aiScore: Int = 0
    let winScore: Int = 5

    // State
    var gameStarted = false
    var isGameOver = false
    var lastUpdate: Date?
    var scoringPause: CGFloat = 0 // brief pause after scoring

    // Input
    var playerTargetY: CGFloat? = nil   // mouse-driven target
    var arrowDirection: CGFloat = 0     // -1 up, +1 down, 0 none
    let arrowSpeed: CGFloat = 200

    // Ball speed
    let baseBallSpeed: CGFloat = 180
    let speedIncrement: CGFloat = 8     // per paddle hit

    // MARK: - Reset

    func reset(size: CGSize) {
        canvasSize = size
        playerScore = 0
        aiScore = 0
        isGameOver = false
        gameStarted = false
        lastUpdate = nil
        playerY = size.height / 2
        aiY = size.height / 2
        playerTargetY = nil
        arrowDirection = 0
        resetBall(toward: .right, size: size)
    }

    enum Side { case left, right }

    func resetBall(toward side: Side, size: CGSize) {
        ballPos = CGPoint(x: size.width / 2, y: size.height / 2)
        let angle = CGFloat.random(in: -0.4...0.4) // slight vertical variance
        let dir: CGFloat = side == .right ? 1 : -1
        ballVel = CGPoint(
            x: dir * baseBallSpeed * cos(angle),
            y: baseBallSpeed * sin(angle)
        )
        scoringPause = 0.5
    }

    // MARK: - Start

    func start() {
        if isGameOver {
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
            playerY = size.height / 2
            aiY = size.height / 2
            resetBall(toward: Bool.random() ? .left : .right, size: size)
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 30.0))
        lastUpdate = date

        guard gameStarted, !isGameOver else { return }

        // Scoring pause
        if scoringPause > 0 {
            scoringPause -= dt
            return
        }

        // --- Player paddle ---
        if let target = playerTargetY {
            playerY = target
        } else if arrowDirection != 0 {
            playerY += arrowDirection * arrowSpeed * dt
        }
        playerY = clampPaddle(playerY, in: size)

        // --- AI paddle ---
        let aiTarget = ballPos.y
        let diff = aiTarget - aiY
        let maxMove = aiMaxSpeed * dt
        let move = min(abs(diff), maxMove) * (diff > 0 ? 1 : -1) * aiReaction
        aiY += move
        aiY = clampPaddle(aiY, in: size)

        // --- Ball ---
        ballPos.x += ballVel.x * dt
        ballPos.y += ballVel.y * dt

        // Top/bottom bounce
        if ballPos.y - ballSize / 2 <= 0 {
            ballPos.y = ballSize / 2
            ballVel.y = abs(ballVel.y)
        } else if ballPos.y + ballSize / 2 >= size.height {
            ballPos.y = size.height - ballSize / 2
            ballVel.y = -abs(ballVel.y)
        }

        // Player paddle collision (left)
        let playerPaddleRight = paddleInset + paddleWidth
        if ballVel.x < 0,
           ballPos.x - ballSize / 2 <= playerPaddleRight,
           ballPos.x - ballSize / 2 >= paddleInset - 2,
           ballPos.y >= playerY - paddleHeight / 2,
           ballPos.y <= playerY + paddleHeight / 2 {
            ballPos.x = playerPaddleRight + ballSize / 2
            ballVel.x = abs(ballVel.x) + speedIncrement
            // Add spin based on hit position
            let hitOffset = (ballPos.y - playerY) / (paddleHeight / 2)
            ballVel.y += hitOffset * 40
        }

        // AI paddle collision (right)
        let aiPaddleLeft = size.width - paddleInset - paddleWidth
        if ballVel.x > 0,
           ballPos.x + ballSize / 2 >= aiPaddleLeft,
           ballPos.x + ballSize / 2 <= aiPaddleLeft + paddleWidth + 2,
           ballPos.y >= aiY - paddleHeight / 2,
           ballPos.y <= aiY + paddleHeight / 2 {
            ballPos.x = aiPaddleLeft - ballSize / 2
            ballVel.x = -(abs(ballVel.x) + speedIncrement)
            let hitOffset = (ballPos.y - aiY) / (paddleHeight / 2)
            ballVel.y += hitOffset * 40
        }

        // Scoring
        if ballPos.x < -ballSize {
            // AI scores
            aiScore += 1
            checkWin(size: size, lastScorer: .right)
        } else if ballPos.x > size.width + ballSize {
            // Player scores
            playerScore += 1
            checkWin(size: size, lastScorer: .left)
        }
    }

    private func checkWin(size: CGSize, lastScorer: Side) {
        if playerScore >= winScore || aiScore >= winScore {
            isGameOver = true
        } else {
            // Reset ball toward the loser
            resetBall(toward: lastScorer == .left ? .right : .left, size: size)
        }
    }

    private func clampPaddle(_ y: CGFloat, in size: CGSize) -> CGFloat {
        let half = paddleHeight / 2
        return min(max(y, half), size.height - half)
    }

    // MARK: - Drawing

    func draw(context: inout GraphicsContext, size: CGSize) {
        let color = Color.white

        // Center dashed line
        var dashY: CGFloat = 2
        while dashY < size.height {
            context.fill(
                Path(CGRect(x: size.width / 2 - 0.5, y: dashY, width: 1, height: 4)),
                with: .color(color.opacity(0.15))
            )
            dashY += 8
        }

        // Player paddle
        let pRect = CGRect(
            x: paddleInset,
            y: playerY - paddleHeight / 2,
            width: paddleWidth,
            height: paddleHeight
        )
        context.fill(Path(pRect), with: .color(color))

        // AI paddle
        let aRect = CGRect(
            x: size.width - paddleInset - paddleWidth,
            y: aiY - paddleHeight / 2,
            width: paddleWidth,
            height: paddleHeight
        )
        context.fill(Path(aRect), with: .color(color))

        // Ball
        if scoringPause <= 0 || Int(scoringPause * 8) % 2 == 0 {
            let bRect = CGRect(
                x: ballPos.x - ballSize / 2,
                y: ballPos.y - ballSize / 2,
                width: ballSize,
                height: ballSize
            )
            context.fill(Path(bRect), with: .color(color))
        }

        // Scores
        let scoreFont = Font.system(size: 16, weight: .bold, design: .monospaced)
        context.draw(
            Text("\(playerScore)").font(scoreFont).foregroundColor(color.opacity(0.6)),
            at: CGPoint(x: size.width / 2 - 24, y: 14)
        )
        context.draw(
            Text("\(aiScore)").font(scoreFont).foregroundColor(color.opacity(0.6)),
            at: CGPoint(x: size.width / 2 + 24, y: 14)
        )

        // Game over
        if isGameOver {
            let won = playerScore >= winScore
            context.draw(
                Text(won ? "YOU WIN" : "YOU LOSE")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(color),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 10)
            )
            context.draw(
                Text("Tap to restart")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            )
        }

        // Start prompt
        if !gameStarted && !isGameOver {
            context.draw(
                Text("Press Space to start")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
    }
}

// MARK: - View

struct PongGameView: View {
    @State private var engine = PongGameEngine()
    @State private var keyMonitor: Any?
    @State private var moveMonitor: Any?

    var body: some View {
        TimelineView(.animation(paused: false)) { timeline in
            Canvas { context, size in
                engine.update(date: timeline.date, size: size)
                engine.draw(context: &context, size: size)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameJumpInput)) { _ in
            engine.start()
        }
        .onAppear { startPongInput() }
        .onDisappear { stopPongInput() }
    }

    // MARK: - Pong-specific input (mouse move + arrow keys)

    private func startPongInput() {
        // Mouse movement → paddle follows Y
        moveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            // Convert mouse location to view-local Y
            // The window coordinate origin is bottom-left; Canvas origin is top-left
            if let window = event.window {
                let windowY = event.locationInWindow.y
                let windowHeight = window.frame.height
                // Flip Y and account for safe area
                let canvasY = windowHeight - windowY - NotchLayout.safeAreaTop
                engine.playerTargetY = canvasY
            }
            return event
        }

        // Arrow keys for paddle movement (held down via key repeat)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            // Up arrow = 126, Down arrow = 125
            if event.keyCode == 126 {
                engine.arrowDirection = event.type == .keyDown ? -1 : 0
                return nil
            } else if event.keyCode == 125 {
                engine.arrowDirection = event.type == .keyDown ? 1 : 0
                return nil
            }
            return event
        }
    }

    private func stopPongInput() {
        if let m = moveMonitor { NSEvent.removeMonitor(m); moveMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
