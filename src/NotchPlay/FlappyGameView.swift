import SwiftUI

// MARK: - Game Engine

final class FlappyGameEngine {
    var birdY: CGFloat = 80
    var velocity: CGFloat = 0
    var pipes: [Pipe] = []
    var score: Int = 0
    var isGameOver = false
    var gameStarted = false
    var lastUpdate: Date?
    var canvasSize: CGSize = CGSize(width: 420, height: 180)

    // Animation
    var animationTimer: CGFloat = 0
    var currentBirdFrame: Int = 0
    let birdFrameInterval: CGFloat = 0.1

    // Parallax background
    var backgroundOffset: CGFloat = 0
    let backgroundSpeed: CGFloat = 30 // much slower than pipes

    struct Pipe {
        var x: CGFloat
        let gapCenterY: CGFloat
        var scored = false
    }

    // Physics
    let gravity: CGFloat = 800
    let flapVelocity: CGFloat = -280
    let birdSize: CGFloat = 20
    let birdX: CGFloat = 80
    let pipeWidth: CGFloat = 30
    let pipeGap: CGFloat = 70
    let pipeSpeed: CGFloat = 140
    let pipeSpawnDistance: CGFloat = 180

    // Pipe entry (rim at gap)
    let pipeEntryHeight: CGFloat = 8

    func reset(size: CGSize) {
        canvasSize = size
        birdY = size.height / 2
        velocity = 0
        pipes = []
        score = 0
        isGameOver = false
        gameStarted = false
        lastUpdate = nil
        animationTimer = 0
        currentBirdFrame = 0
        backgroundOffset = 0
    }

    func flap() {
        if isGameOver {
            reset(size: canvasSize)
            return
        }

        if !gameStarted {
            gameStarted = true
        }

        velocity = flapVelocity
    }

    func update(date: Date, size: CGSize) {
        canvasSize = size

        guard !isGameOver else { return }

        guard let last = lastUpdate else {
            lastUpdate = date
            birdY = size.height / 2
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 30.0))
        lastUpdate = date

        // Bird animation frames (always animate, even before start)
        animationTimer += dt
        if animationTimer >= birdFrameInterval {
            animationTimer -= birdFrameInterval
            currentBirdFrame = (currentBirdFrame + 1) % 4
        }

        guard gameStarted else { return }

        // Scroll background (parallax)
        backgroundOffset += backgroundSpeed * dt

        // Physics
        velocity += gravity * dt
        birdY += velocity * dt

        // Boundaries
        if birdY < 0 {
            birdY = 0
            velocity = 0
            gameOver()
            return
        }
        if birdY + birdSize > size.height {
            birdY = size.height - birdSize
            gameOver()
            return
        }

        // Move pipes
        for i in pipes.indices {
            pipes[i].x -= pipeSpeed * dt
        }

        // Score
        for i in pipes.indices where !pipes[i].scored && pipes[i].x + pipeWidth < birdX {
            pipes[i].scored = true
            score += 1
        }

        // Remove off-screen
        pipes.removeAll { $0.x + pipeWidth < -20 }

        // Spawn
        let lastX = pipes.last?.x ?? -pipeSpawnDistance
        if lastX < size.width - pipeSpawnDistance {
            let minGapY = pipeGap / 2 + 10
            let maxGapY = size.height - pipeGap / 2 - 10
            guard minGapY < maxGapY else { return }
            let gapY = CGFloat.random(in: minGapY...maxGapY)
            pipes.append(Pipe(x: size.width + 10, gapCenterY: gapY))
        }

        // Collision
        let birdRect = CGRect(
            x: birdX + 2, y: birdY + 2,
            width: birdSize - 4, height: birdSize - 4
        )
        for pipe in pipes {
            guard birdRect.maxX > pipe.x && birdRect.minX < pipe.x + pipeWidth else { continue }
            let topBottom = pipe.gapCenterY - pipeGap / 2
            let bottomTop = pipe.gapCenterY + pipeGap / 2
            if birdRect.minY < topBottom || birdRect.maxY > bottomTop {
                gameOver()
                return
            }
        }
    }

    private func gameOver() {
        isGameOver = true
    }

    // MARK: - Bird

    var birdImageName: String {
        let frame = currentBirdFrame + 1 // 1-based
        return "bird_\(frame)"
    }

    /// Bird tilt angle based on velocity: nose up when flapping, nose down when falling
    var birdRotation: CGFloat {
        if !gameStarted && !isGameOver { return 0 }
        // Map velocity to angle: flapVelocity (-280) → -25°, terminal (~400) → +45°
        let clampedVel = min(max(velocity, -300), 400)
        return clampedVel / 400 * 45
    }

    // MARK: - Drawing

    func draw(context: inout GraphicsContext, size: CGSize) {
        drawBackground(context: &context, size: size)
        drawPipes(context: &context, size: size)
        drawBird(context: &context, size: size)
        drawUI(context: &context, size: size)
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        guard let bgImage = NSImage(named: "bird_background") else { return }
        let img = Image(nsImage: bgImage)

        // Calculate tile width maintaining aspect ratio to fill height
        let aspectRatio = bgImage.size.width / max(bgImage.size.height, 1)
        let tileWidth = size.height * aspectRatio
        let tileW = max(tileWidth, 1)

        // Loop offset so it wraps seamlessly
        let offset = backgroundOffset.truncatingRemainder(dividingBy: tileW)

        // Round coordinates to whole points to prevent black seam lines from sub-pixel rendering
        var x = round(-offset)
        while x < size.width {
            context.draw(img, in: CGRect(x: x, y: 0, width: tileWidth, height: size.height))
            x = round(x + tileWidth)
        }
    }

    private func drawPipes(context: inout GraphicsContext, size: CGSize) {
        guard let pipeImg = NSImage(named: "pipe"),
              let pipeEntryImg = NSImage(named: "pipe_entry") else { return }

        let pipeImage = Image(nsImage: pipeImg)
        let pipeEntryImage = Image(nsImage: pipeEntryImg)
        let pipeTileHeight = pipeImg.size.height

        for pipe in pipes {
            let topBottom = pipe.gapCenterY - pipeGap / 2  // bottom of top pipe (entry faces down)
            let bottomTop = pipe.gapCenterY + pipeGap / 2  // top of bottom pipe (entry faces up)

            // --- Top pipe (hangs from ceiling, entry at bottom) ---
            let topBodyHeight = max(topBottom - pipeEntryHeight, 0)
            if topBodyHeight > 0 {
                drawTiledPipe(context: &context, img: pipeImage, x: pipe.x, y: 0, height: topBodyHeight, tileHeight: pipeTileHeight)
            }
            // pipe_entry at bottom of top pipe (entrance faces down into gap)
            context.draw(pipeEntryImage, in: CGRect(x: pipe.x, y: topBottom - pipeEntryHeight, width: pipeWidth, height: pipeEntryHeight))

            // --- Bottom pipe (rises from floor, entry at top) ---
            // pipe_entry at top of bottom pipe (entrance faces up into gap)
            context.draw(pipeEntryImage, in: CGRect(x: pipe.x, y: bottomTop, width: pipeWidth, height: pipeEntryHeight))
            let bottomBodyY = bottomTop + pipeEntryHeight
            let bottomBodyHeight = max(size.height - bottomBodyY, 0)
            if bottomBodyHeight > 0 {
                drawTiledPipe(context: &context, img: pipeImage, x: pipe.x, y: bottomBodyY, height: bottomBodyHeight, tileHeight: pipeTileHeight)
            }
        }
    }

    private func drawTiledPipe(context: inout GraphicsContext, img: Image, x: CGFloat, y: CGFloat, height: CGFloat, tileHeight: CGFloat) {
        let tileH = max(tileHeight, 1)
        var drawY = y
        while drawY < y + height {
            let sliceHeight = min(tileH, y + height - drawY)
            context.draw(img, in: CGRect(x: x, y: drawY, width: pipeWidth, height: sliceHeight))
            drawY += tileH
        }
    }

    private func drawBird(context: inout GraphicsContext, size: CGSize) {
        guard let birdNSImage = NSImage(named: birdImageName) else { return }
        let img = Image(nsImage: birdNSImage)
        let birdRect = CGRect(x: birdX, y: birdY, width: birdSize, height: birdSize)

        // Apply rotation around bird center
        var birdContext = context
        let center = CGPoint(x: birdRect.midX, y: birdRect.midY)
        birdContext.translateBy(x: center.x, y: center.y)
        birdContext.rotate(by: .degrees(Double(birdRotation)))
        birdContext.translateBy(x: -center.x, y: -center.y)
        birdContext.draw(img, in: birdRect)
    }

    private func drawUI(context: inout GraphicsContext, size: CGSize) {
        // Score
        let scoreText = Text(String(format: "%05d", score))
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
        context.draw(scoreText, at: CGPoint(x: size.width - 50, y: 20))

        // Game over
        if isGameOver {
            context.draw(
                Text("GAME OVER").font(.system(size: 16, weight: .bold)).foregroundColor(.white),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 12)
            )
            context.draw(
                Text("Tap to restart").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            )
        }

        // Start prompt
        if !gameStarted && !isGameOver {
            context.draw(
                Text("Press Space to start").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
    }
}

// MARK: - View

struct FlappyGameView: View {
    @State private var engine = FlappyGameEngine()

    var body: some View {
        TimelineView(.animation(paused: false)) { timeline in
            Canvas { context, size in
                engine.update(date: timeline.date, size: size)
                engine.draw(context: &context, size: size)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameJumpInput)) { _ in
            engine.flap()
        }
    }
}
