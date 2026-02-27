import SwiftUI

// MARK: - Game Engine (class - mutations don't trigger SwiftUI re-renders)

final class DinoGameEngine {
    var playerY: CGFloat = 0
    var velocity: CGFloat = 0
    var obstacles: [Obstacle] = []
    var score: Int = 0
    var isGameOver = false
    var gameStarted = false
    var lastUpdate: Date?
    var canvasSize: CGSize = CGSize(width: 420, height: 180)

    // Animation
    var animationTimer: CGFloat = 0
    var currentRunFrame: Int = 0
    let runFrameInterval: CGFloat = 0.1 // switch frames every 0.1s

    // Clouds
    struct Cloud {
        var x: CGFloat
        let y: CGFloat
        let scale: CGFloat // 0.5–1.0 for variety
    }
    var clouds: [Cloud] = []
    let cloudSpeed: CGFloat = 30 // much slower than game scroll
    let cloudSpawnChance: CGFloat = 0.4 // per second
    var cloudTimer: CGFloat = 0

    struct Obstacle {
        var x: CGFloat
        let height: CGFloat
        let usesAltTexture: Bool
        var scored = false
    }

    // Physics
    let gravity: CGFloat = 1200
    let jumpVelocity: CGFloat = -450
    let playerSize: CGFloat = 26
    let groundHeight: CGFloat = 28
    let playerX: CGFloat = 50
    let baseSpeed: CGFloat = 180
    let obstacleWidth: CGFloat = 18
    let minObstacleHeight: CGFloat = 22
    let maxObstacleHeight: CGFloat = 40
    let minSpawnDistance: CGFloat = 150
    let maxSpawnDistance: CGFloat = 320
    var nextSpawnDistance: CGFloat = 200

    var scrollSpeed: CGFloat {
        baseSpeed + CGFloat(score) * 3
    }

    func groundY(in size: CGSize) -> CGFloat {
        size.height - groundHeight
    }

    var isOnGround: Bool {
        playerY >= groundY(in: canvasSize) - playerSize - 1
    }

    func reset(size: CGSize) {
        canvasSize = size
        playerY = groundY(in: size) - playerSize
        velocity = 0
        obstacles = []
        score = 0
        isGameOver = false
        gameStarted = false
        lastUpdate = nil
        animationTimer = 0
        currentRunFrame = 0
        nextSpawnDistance = CGFloat.random(in: minSpawnDistance...maxSpawnDistance)
        clouds = []
        cloudTimer = 0
    }

    func jump() {
        if isGameOver {
            reset(size: canvasSize)
            return
        }

        if !gameStarted {
            gameStarted = true
        }

        let ground = groundY(in: canvasSize) - playerSize
        if playerY >= ground - 1 {
            velocity = jumpVelocity
        }
    }

    func update(date: Date, size: CGSize) {
        canvasSize = size

        guard !isGameOver else { return }

        guard let last = lastUpdate else {
            lastUpdate = date
            playerY = groundY(in: size) - playerSize
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 30.0))
        lastUpdate = date

        guard gameStarted else { return }

        let ground = groundY(in: size) - playerSize

        // Animation frames
        animationTimer += dt
        if animationTimer >= runFrameInterval {
            animationTimer -= runFrameInterval
            currentRunFrame = (currentRunFrame + 1) % 2
        }

        // Clouds
        for i in clouds.indices {
            clouds[i].x -= cloudSpeed * dt
        }
        clouds.removeAll { $0.x < -40 }
        cloudTimer += dt
        if cloudTimer >= 1.0 {
            cloudTimer -= 1.0
            if CGFloat.random(in: 0...1) < cloudSpawnChance {
                let ground = groundY(in: size)
                let y = CGFloat.random(in: 10...(ground * 0.45))
                let scale = CGFloat.random(in: 0.5...1.0)
                clouds.append(Cloud(x: size.width + 20, y: y, scale: scale))
            }
        }

        // Physics
        velocity += gravity * dt
        playerY += velocity * dt

        if playerY >= ground {
            playerY = ground
            velocity = 0
        }

        // Move obstacles
        for i in obstacles.indices {
            obstacles[i].x -= scrollSpeed * dt
        }

        // Score
        for i in obstacles.indices where !obstacles[i].scored && obstacles[i].x + obstacleWidth < playerX {
            obstacles[i].scored = true
            score += 1
        }

        // Remove off-screen
        obstacles.removeAll { $0.x + obstacleWidth < -20 }

        // Spawn
        let lastX = obstacles.last?.x ?? -nextSpawnDistance
        if lastX < size.width - nextSpawnDistance {
            let h = CGFloat.random(in: minObstacleHeight...maxObstacleHeight)
            obstacles.append(Obstacle(x: size.width + 10, height: h, usesAltTexture: Bool.random()))
            nextSpawnDistance = CGFloat.random(in: minSpawnDistance...maxSpawnDistance)
        }

        // Collision
        let playerRect = CGRect(
            x: playerX + 2, y: playerY + 2,
            width: playerSize - 4, height: playerSize - 4
        )
        for obs in obstacles {
            let obsRect = CGRect(
                x: obs.x, y: groundY(in: size) - obs.height,
                width: obstacleWidth, height: obs.height
            )
            if playerRect.intersects(obsRect) {
                isGameOver = true
                return
            }
        }
    }

    func dinoImageName() -> String {
        if isGameOver || !isOnGround {
            return "dino_idle"
        }
        return currentRunFrame == 0 ? "dino_run_1" : "dino_run_2"
    }

    func draw(context: inout GraphicsContext, size: CGSize) {
        let ground = groundY(in: size)

        // Clouds (behind everything)
        if let cloudNS = NSImage(named: "dino_cloud") {
            let cloudImg = Image(nsImage: cloudNS)
            let baseW: CGFloat = 24
            let baseH: CGFloat = 12
            for cloud in clouds {
                let w = baseW * cloud.scale
                let h = baseH * cloud.scale
                context.draw(cloudImg, in: CGRect(x: cloud.x, y: cloud.y, width: w, height: h))
            }
        }

        // Ground line
        context.fill(
            Path(CGRect(x: 0, y: ground, width: size.width, height: 1)),
            with: .color(.white.opacity(0.3))
        )

        // Ground dashes
        var dashX: CGFloat = 0
        while dashX < size.width {
            context.fill(
                Path(CGRect(x: dashX, y: ground + 4, width: 6, height: 1)),
                with: .color(.white.opacity(0.15))
            )
            dashX += 14
        }

        // Player (dino sprite)
        if let dinoImage = NSImage(named: dinoImageName()) {
            let img = Image(nsImage: dinoImage)
            let playerRect = CGRect(x: playerX, y: playerY, width: playerSize, height: playerSize)
            context.draw(img, in: playerRect)
        }

        // Obstacles (cactus sprites)
        for obs in obstacles {
            let cactusName = obs.usesAltTexture ? "cactus_2" : "cactus"
            let rect = CGRect(
                x: obs.x, y: ground - obs.height,
                width: obstacleWidth, height: obs.height
            )
            if let cactusImage = NSImage(named: cactusName) {
                context.draw(Image(nsImage: cactusImage), in: rect)
            }
        }

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

            // Restart icon
            let restartSize: CGFloat = 20
            if let restartNS = NSImage(named: "dino_restart") {
                let restartImg = Image(nsImage: restartNS)
                context.draw(restartImg, in: CGRect(
                    x: size.width / 2 - restartSize / 2,
                    y: size.height / 2 + 4,
                    width: restartSize,
                    height: restartSize
                ))
            }
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

struct DinoGameView: View {
    @State private var engine = DinoGameEngine()

    var body: some View {
        TimelineView(.animation(paused: false)) { timeline in
            Canvas { context, size in
                engine.update(date: timeline.date, size: size)
                engine.draw(context: &context, size: size)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameJumpInput)) { _ in
            engine.jump()
        }
    }
}
