import SwiftUI

// MARK: - Data Types

struct StackBlock {
    var x: CGFloat      // left edge
    var width: CGFloat
    var hue: CGFloat
}

struct FallingPiece {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var velocity: CGFloat
    var opacity: CGFloat
    var hue: CGFloat
}

// MARK: - Game Engine

final class StackGameEngine {

    // Stack
    var blocks: [StackBlock] = []
    var currentBlock: StackBlock?
    var fallingPieces: [FallingPiece] = []

    // State
    var score: Int = 0
    var isGameOver = false
    var gameStarted = false
    var lastUpdate: Date?
    var time: CGFloat = 0
    var canvasSize: CGSize = CGSize(width: 420, height: 180)

    // Camera
    var cameraY: CGFloat = 0
    var targetCameraY: CGFloat = 0

    // Motion
    var movingRight = true
    var blockX: CGFloat = 0

    // Constants
    let blockHeight: CGFloat = 10
    let depth: CGFloat = 5        // 3D extrusion depth
    let skew: CGFloat = 4         // 3D horizontal skew
    let baseWidth: CGFloat = 80
    let baseSpeed: CGFloat = 100
    let gravity: CGFloat = 400

    var moveSpeed: CGFloat {
        baseSpeed + CGFloat(score) * 2.5
    }

    // MARK: - Layout helpers

    /// Y position (in world space) for block at given stack index
    func worldY(for index: Int) -> CGFloat {
        return CGFloat(index) * blockHeight
    }

    /// Convert world Y to screen Y (0 = bottom of canvas)
    func screenY(worldY wy: CGFloat, in size: CGSize) -> CGFloat {
        let bottomMargin: CGFloat = 20
        return size.height - bottomMargin - wy + cameraY
    }

    // MARK: - Hue

    func hueFor(index: Int) -> CGFloat {
        let h = 0.0 + CGFloat(index) * 0.05 + time * 0.02
        return h.truncatingRemainder(dividingBy: 1.0)
    }

    // MARK: - Reset

    func reset(size: CGSize) {
        canvasSize = size
        blocks = []
        fallingPieces = []
        score = 0
        isGameOver = false
        gameStarted = false
        lastUpdate = nil
        time = 0
        cameraY = 0
        targetCameraY = 0
        movingRight = true
        blockX = 0
        currentBlock = nil

        // Place initial foundation block centered
        let startX = (size.width - baseWidth) / 2
        blocks.append(StackBlock(x: startX, width: baseWidth, hue: hueFor(index: 0)))
    }

    // MARK: - Input

    func tap() {
        if isGameOver {
            reset(size: canvasSize)
            return
        }

        if !gameStarted {
            gameStarted = true
            spawnBlock()
            return
        }

        guard let current = currentBlock else { return }
        placeBlock(current)
    }

    // MARK: - Spawn

    private func spawnBlock() {
        guard let top = blocks.last else { return }
        let hue = hueFor(index: blocks.count)
        let startX: CGFloat = movingRight ? -top.width : canvasSize.width
        currentBlock = StackBlock(x: startX, width: top.width, hue: hue)
        blockX = startX
    }

    // MARK: - Place

    private func placeBlock(_ block: StackBlock) {
        guard let top = blocks.last else { return }

        let topLeft = top.x
        let topRight = top.x + top.width
        let curLeft = block.x
        let curRight = block.x + block.width

        // Calculate overlap
        let overlapLeft = max(topLeft, curLeft)
        let overlapRight = min(topRight, curRight)
        let overlapWidth = overlapRight - overlapLeft

        if overlapWidth <= 0 {
            // No overlap - game over
            // Make the whole block fall
            let wy = worldY(for: blocks.count)
            let sy = screenY(worldY: wy, in: canvasSize)
            fallingPieces.append(FallingPiece(
                x: block.x, y: sy, width: block.width,
                velocity: 0, opacity: 1.0, hue: block.hue
            ))
            currentBlock = nil
            isGameOver = true
            return
        }

        // Place the overlapping portion
        let placed = StackBlock(x: overlapLeft, width: overlapWidth, hue: block.hue)
        blocks.append(placed)
        score += 1

        // Create falling piece for the cut-off part
        let wy = worldY(for: blocks.count - 1)
        let sy = screenY(worldY: wy, in: canvasSize)

        if curLeft < topLeft {
            // Overhang on the left
            let cutWidth = topLeft - curLeft
            fallingPieces.append(FallingPiece(
                x: curLeft, y: sy, width: cutWidth,
                velocity: 0, opacity: 1.0, hue: block.hue
            ))
        }
        if curRight > topRight {
            // Overhang on the right
            let cutWidth = curRight - topRight
            fallingPieces.append(FallingPiece(
                x: topRight, y: sy, width: cutWidth,
                velocity: 0, opacity: 1.0, hue: block.hue
            ))
        }

        // Update camera target
        let visibleBlocks: CGFloat = 5
        let stackTop = worldY(for: blocks.count)
        let threshold = visibleBlocks * blockHeight
        if stackTop > threshold {
            targetCameraY = stackTop - threshold
        }

        // Alternate direction
        movingRight.toggle()

        // Spawn next
        currentBlock = nil
        spawnBlock()
    }

    // MARK: - Update

    func update(date: Date, size: CGSize) {
        canvasSize = size

        guard let last = lastUpdate else {
            lastUpdate = date
            if blocks.isEmpty {
                reset(size: size)
            }
            return
        }

        let dt = CGFloat(min(date.timeIntervalSince(last), 1.0 / 30.0))
        lastUpdate = date
        time += dt

        guard gameStarted else { return }
        guard !isGameOver else {
            // Still update falling pieces
            updateFallingPieces(dt: dt)
            return
        }

        // Move current block
        if var block = currentBlock {
            let speed = moveSpeed
            if movingRight {
                blockX += speed * dt
                if blockX > size.width {
                    movingRight = false
                }
            } else {
                blockX -= speed * dt
                if blockX + block.width < 0 {
                    movingRight = true
                }
            }
            block.x = blockX
            currentBlock = block
        }

        // Smooth camera
        cameraY += (targetCameraY - cameraY) * min(dt * 5, 1.0)

        // Update falling pieces
        updateFallingPieces(dt: dt)
    }

    private func updateFallingPieces(dt: CGFloat) {
        for i in fallingPieces.indices {
            fallingPieces[i].velocity += gravity * dt
            fallingPieces[i].y += fallingPieces[i].velocity * dt
            fallingPieces[i].opacity -= dt * 1.5
        }
        fallingPieces.removeAll { $0.opacity <= 0 || $0.y > canvasSize.height + 50 }
    }

    // MARK: - Drawing

    func draw(context: inout GraphicsContext, size: CGSize) {
        drawBackground(context: &context, size: size)
        drawStack(context: &context, size: size)
        drawCurrentBlock(context: &context, size: size)
        drawFallingPieces(context: &context, size: size)
        drawUI(context: &context, size: size)
    }

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        let bgHue = (time * 0.01).truncatingRemainder(dividingBy: 1.0)
        let topColor = Color(hue: bgHue, saturation: 0.3, brightness: 0.12)
        let bottomColor = Color(hue: (bgHue + 0.1).truncatingRemainder(dividingBy: 1.0), saturation: 0.2, brightness: 0.22)

        let gradient = Gradient(colors: [topColor, bottomColor])
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
        )
    }

    private func drawBlock3D(context: inout GraphicsContext, x: CGFloat, screenY sy: CGFloat, width: CGFloat, hue: CGFloat, opacity: CGFloat = 1.0) {
        let h = blockHeight
        let d = depth
        let sk = skew

        let sat: CGFloat = 0.65

        // Colors for 3 faces
        let topColor = Color(hue: hue, saturation: sat, brightness: 1.0).opacity(opacity)
        let leftColor = Color(hue: hue, saturation: sat, brightness: 0.75).opacity(opacity)
        let rightColor = Color(hue: hue, saturation: sat, brightness: 0.55).opacity(opacity)

        // Front face (left side visible face)
        let leftFace = Path { p in
            p.move(to: CGPoint(x: x, y: sy))
            p.addLine(to: CGPoint(x: x, y: sy + h))
            p.addLine(to: CGPoint(x: x + sk, y: sy + h - d))
            p.addLine(to: CGPoint(x: x + sk, y: sy - d))
            p.closeSubpath()
        }
        context.fill(leftFace, with: .color(leftColor))

        // Top face
        let topFace = Path { p in
            p.move(to: CGPoint(x: x, y: sy))
            p.addLine(to: CGPoint(x: x + sk, y: sy - d))
            p.addLine(to: CGPoint(x: x + width + sk, y: sy - d))
            p.addLine(to: CGPoint(x: x + width, y: sy))
            p.closeSubpath()
        }
        context.fill(topFace, with: .color(topColor))

        // Right side face
        let rightFace = Path { p in
            p.move(to: CGPoint(x: x + width, y: sy))
            p.addLine(to: CGPoint(x: x + width, y: sy + h))
            p.addLine(to: CGPoint(x: x + width + sk, y: sy + h - d))
            p.addLine(to: CGPoint(x: x + width + sk, y: sy - d))
            p.closeSubpath()
        }
        context.fill(rightFace, with: .color(rightColor))

        // Front face (main visible rectangle)
        let frontFace = Path(CGRect(x: x, y: sy, width: width, height: h))
        let frontColor = Color(hue: hue, saturation: sat, brightness: 0.85).opacity(opacity)
        context.fill(frontFace, with: .color(frontColor))
    }

    private func drawStack(context: inout GraphicsContext, size: CGSize) {
        for (i, block) in blocks.enumerated() {
            let wy = worldY(for: i)
            let sy = screenY(worldY: wy, in: size)

            // Skip if off screen
            if sy + blockHeight < -depth || sy - depth > size.height + 10 { continue }

            drawBlock3D(context: &context, x: block.x, screenY: sy, width: block.width, hue: block.hue)
        }
    }

    private func drawCurrentBlock(context: inout GraphicsContext, size: CGSize) {
        guard let block = currentBlock else { return }
        let wy = worldY(for: blocks.count)
        let sy = screenY(worldY: wy, in: size)
        drawBlock3D(context: &context, x: block.x, screenY: sy, width: block.width, hue: block.hue)
    }

    private func drawFallingPieces(context: inout GraphicsContext, size: CGSize) {
        for piece in fallingPieces {
            drawBlock3D(
                context: &context, x: piece.x, screenY: piece.y,
                width: piece.width, hue: piece.hue, opacity: max(piece.opacity, 0)
            )
        }
    }

    private func drawUI(context: inout GraphicsContext, size: CGSize) {
        // Score
        let scoreText = Text(String(score))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.8))
        context.draw(scoreText, at: CGPoint(x: size.width / 2, y: 16))

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

        if !gameStarted && !isGameOver {
            context.draw(
                Text("Press Space to start").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: size.width / 2, y: size.height / 2)
            )
        }
    }
}

// MARK: - View

struct StackGameView: View {
    @State private var engine = StackGameEngine()

    var body: some View {
        TimelineView(.animation(paused: false)) { timeline in
            Canvas { context, size in
                engine.update(date: timeline.date, size: size)
                engine.draw(context: &context, size: size)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameJumpInput)) { _ in
            engine.tap()
        }
    }
}
