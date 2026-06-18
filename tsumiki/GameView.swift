import UIKit

// MARK: - Constants

private let BASE: CGFloat = 240
private let BLOCK_H: CGFloat = 52
private let PERFECT_TOL: CGFloat = 8
private let AMPLITUDE: CGFloat = 340
private let ISO_X: CGFloat = cos(.pi / 6)  // ≈ 0.866

private let SKY_DUSK: [(CGFloat, CGFloat, CGFloat)] = [
    (71/255, 48/255, 102/255),
    (183/255, 92/255, 126/255),
    (242/255, 161/255, 124/255)
]
private let SKY_NIGHT: [(CGFloat, CGFloat, CGFloat)] = [
    (9/255, 13/255, 38/255),
    (27/255, 34/255, 71/255),
    (56/255, 50/255, 102/255)
]
private let SKY_DAWN: [(CGFloat, CGFloat, CGFloat)] = [
    (48/255, 70/255, 124/255),
    (236/255, 145/255, 135/255),
    (252/255, 213/255, 170/255)
]
private let SKY_DEEP_NIGHT: [(CGFloat, CGFloat, CGFloat)] = [
    (2/255, 4/255, 14/255),
    (10/255, 14/255, 32/255),
    (22/255, 24/255, 56/255)
]

// MARK: - Score Comments

private let SCORE_COMMENTS: [(range: ClosedRange<Int>, lines: [String])] = [
    (0...0, [
        "もう一度挑戦！",
        "肩慣らし、肩慣らし",
        "ここからここから",
        "次はきっと積める"
    ]),
    (1...2, [
        "あとちょっと",
        "感触は掴めた？",
        "焦らず、ゆっくり",
        "もう少しで形になる"
    ]),
    (3...5, [
        "いいかんじ",
        "リズムが見えてきた",
        "悪くない手つき",
        "目が慣れてきた？"
    ]),
    (6...9, [
        "うまいね！",
        "なかなかやるね",
        "順調、順調",
        "コツを掴んだみたい"
    ]),
    (10...14, [
        "すごい！",
        "リズム感あるね",
        "丁寧な仕事",
        "もう上級者"
    ]),
    (15...19, [
        "ほんとに上手",
        "もう手慣れたもの",
        "美しい積み",
        "頂が見えてきた"
    ]),
    (20...29, [
        "見事な腕前！",
        "巨匠の手つき",
        "風格がある",
        "もはや職人"
    ]),
    (30...39, [
        "天を目指す者",
        "雲が近い",
        "塔師の領分",
        "黄昏が遠ざかる"
    ]),
    (40...49, [
        "神業の域",
        "息を呑む高さ",
        "夜空に届きそう",
        "並の積み手じゃない"
    ]),
    (50...59, [
        "明けの空に届いた",
        "夜を越えてきたね",
        "暁の高み",
        "ここまで来た人は数人"
    ]),
    (60...69, [
        "光が見えるね",
        "朝日が眩しい",
        "雲海の入り口",
        "天をかすめてる"
    ]),
    (70...79, [
        "もはや伝説",
        "雲海の上を歩く",
        "鳥より高く",
        "ここは別世界"
    ]),
    (80...89, [
        "神々の住む高さ",
        "風がうたう",
        "誰も知らない景色",
        "歴史に残る積み"
    ]),
    (90...99, [
        "あと少しで星に届く",
        "宇宙が近い",
        "限界の縁",
        "100段が見える"
    ])
]

private let LEGEND_COMMENTS: [String] = [
    "夜がまた来た",
    "宇宙の扉、開く",
    "あなた、神様？",
    "もはや神話",
    "100段の主",
    "積み積み究極形態",
    "歴史に名を刻んだ"
]

private func pickScoreComment(score: Int) -> String {
    if score >= 100 {
        return LEGEND_COMMENTS.randomElement() ?? ""
    }
    for bucket in SCORE_COMMENTS where bucket.range.contains(score) {
        return bucket.lines.randomElement() ?? ""
    }
    return ""
}

// MARK: - Sky Palette

private struct SkyPalette {
    let top: CGColor
    let mid: CGColor
    let bottom: CGColor
    let darkness: CGFloat     // controls star and moon visibility
    let dawnAmount: CGFloat   // controls sun visibility
}

private func lerpRGB(
    _ c1: (CGFloat, CGFloat, CGFloat),
    _ c2: (CGFloat, CGFloat, CGFloat),
    t: CGFloat
) -> CGColor {
    CGColor(red:   c1.0 + (c2.0 - c1.0) * t,
            green: c1.1 + (c2.1 - c1.1) * t,
            blue:  c1.2 + (c2.2 - c1.2) * t,
            alpha: 1)
}

private func skyPalette(forCamY camY: CGFloat) -> SkyPalette {
    let n = max(0, camY / 52)  // BLOCK_H = 52
    if n < 50 {
        let t = min(1, n / 50)
        return SkyPalette(
            top:    lerpRGB(SKY_DUSK[0], SKY_NIGHT[0], t: t),
            mid:    lerpRGB(SKY_DUSK[1], SKY_NIGHT[1], t: t),
            bottom: lerpRGB(SKY_DUSK[2], SKY_NIGHT[2], t: t),
            darkness: t,
            dawnAmount: 0
        )
    } else if n < 100 {
        let t = (n - 50) / 50
        return SkyPalette(
            top:    lerpRGB(SKY_NIGHT[0], SKY_DAWN[0], t: t),
            mid:    lerpRGB(SKY_NIGHT[1], SKY_DAWN[1], t: t),
            bottom: lerpRGB(SKY_NIGHT[2], SKY_DAWN[2], t: t),
            darkness: max(0.18, 1 - 0.82 * t),
            dawnAmount: t
        )
    } else {
        let t = min(1, (n - 100) / 50)
        return SkyPalette(
            top:    lerpRGB(SKY_DAWN[0], SKY_DEEP_NIGHT[0], t: t),
            mid:    lerpRGB(SKY_DAWN[1], SKY_DEEP_NIGHT[1], t: t),
            bottom: lerpRGB(SKY_DAWN[2], SKY_DEEP_NIGHT[2], t: t),
            darkness: 0.18 + 0.82 * t,
            dawnAmount: max(0, 1 - t)
        )
    }
}

private struct StarDot {
    let x, y, size, phase: CGFloat
}

private let STARS: [StarDot] = (0..<90).map { i in
    let fi = CGFloat(i)
    let s  = sin(fi * 127.1) * 43758.5453
    let r  = s - floor(s)
    let s2 = sin(fi * 311.7) * 12543.853
    let r2 = s2 - floor(s2)
    return StarDot(x: r, y: r2 * 0.75, size: 0.6 + r * r2 * 1.6, phase: r2 * 6.28)
}

// MARK: - Game Data

private struct Block { var x, z, w, d: CGFloat }

private struct MovingBlock {
    enum Axis { case x, z }
    var x, z, w, d: CGFloat
    var axis: Axis
    var t0: TimeInterval
    var idx: Int
}

private struct FallingPiece {
    var x, z, w, d: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var hue: CGFloat
    var alpha: CGFloat = 1
}

private struct Ring {
    var x, z, y: CGFloat
    var r: CGFloat = 0
    var alpha: CGFloat = 0.9
}

private enum GamePhase { case title, playing, over, viewingTower }

private let BEST_SCORE_KEY = "tsumiki.bestScore"

// MARK: - Delegate

protocol GameViewDelegate: AnyObject {
    func gameViewDidRequestSettings()
    func gameViewDidRequestShare(score: Int, image: UIImage?)
    func gameViewDidRequestMainMenu(score: Int, completion: @escaping () -> Void)
}

// MARK: - GameView

final class GameView: UIView {

    weak var delegate: GameViewDelegate?

    // State
    private var stack: [Block] = []
    private var moving: MovingBlock?
    private var pieces: [FallingPiece] = []
    private var rings: [Ring] = []
    private var camY: CGFloat = 0
    private var camTarget: CGFloat = 0
    private var t: TimeInterval = 0
    private var phase: GamePhase = .title
    private var combo: Int = 0
    private var hue0: CGFloat = 0
    private var overAt: TimeInterval = 0
    private var score: Int = 0
    private var best: Int = 0
    private var comboMsg: (n: Int, until: TimeInterval)?
    private var lastComment: String = ""

    // Tap zones (set during draw, consumed in handleTap)
    private var settingsBtnRect: CGRect = .zero
    private var retryBtnRect: CGRect = .zero
    private var menuBtnRect: CGRect = .zero
    private var shareBtnRect: CGRect = .zero
    private var viewTowerBtnRect: CGRect = .zero
    private var closeBtnRect: CGRect = .zero

    // Tower viewing state
    private var preViewCamY: CGFloat = 0
    private var panStartCamY: CGFloat = 0

    private var displayLink: CADisplayLink?

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = true
        clearsContextBeforeDrawing = false
        backgroundColor = UIColor(red: 71/255, green: 48/255, blue: 102/255, alpha: 1)
        best = UserDefaults.standard.integer(forKey: BEST_SCORE_KEY)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit { displayLink?.invalidate() }

    // MARK: Game Loop

    @objc private func tick(_ link: CADisplayLink) {
        t = link.timestamp
        stepPhysics()
        setNeedsDisplay()
    }

    private func stepPhysics() {
        if phase != .viewingTower {
            camY += (camTarget - camY) * 0.08
        }
        for i in pieces.indices {
            pieces[i].vy += 0.5
            pieces[i].y -= pieces[i].vy
            pieces[i].alpha = max(0, pieces[i].alpha - 0.006)
        }
        pieces = pieces.filter { $0.alpha > 0.02 && $0.y > camY - 2000 }
        for i in rings.indices {
            rings[i].r += 9
            rings[i].alpha -= 0.035
        }
        rings = rings.filter { $0.alpha > 0 }
    }

    // MARK: Input

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        let p = sender.location(in: self)

        switch phase {
        case .title:
            if settingsBtnRect.contains(p) {
                delegate?.gameViewDidRequestSettings()
                return
            }
            resetGame(); phase = .playing
        case .playing:
            drop()
        case .over:
            guard t - overAt > 0.4 else { return }
            if shareBtnRect.contains(p) {
                let image = makeShareImage(score: score)
                delegate?.gameViewDidRequestShare(score: score, image: image)
                return
            }
            if viewTowerBtnRect.contains(p) {
                preViewCamY = camY
                camY = CGFloat(max(stack.count - 1, 0)) * BLOCK_H
                camTarget = camY
                phase = .viewingTower
                return
            }
            if menuBtnRect.contains(p) {
                let finalScore = score
                delegate?.gameViewDidRequestMainMenu(score: finalScore) { [weak self] in
                    self?.phase = .title
                }
                return
            }
            if retryBtnRect.contains(p) {
                resetGame(); phase = .playing
                return
            }
        case .viewingTower:
            if closeBtnRect.contains(p) {
                camY = preViewCamY
                camTarget = preViewCamY
                phase = .over
                return
            }
        }
    }

    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        guard phase == .viewingTower else { return }
        let translation = sender.translation(in: self).y
        let baseS = min(bounds.width, 560) / 760
        switch sender.state {
        case .began:
            panStartCamY = camY
        case .changed:
            // Finger-down drags the tower down (camera moves up the world).
            // Divide by scale so 1pt of finger maps to 1pt on screen, then
            // multiply so a single swipe traverses several stories at a time.
            let panSpeed: CGFloat = 2.2
            let raw = panStartCamY + (translation / max(baseS, 0.001)) * panSpeed
            let maxCamY = CGFloat(max(stack.count - 1, 0)) * BLOCK_H + BLOCK_H * 2
            let minCamY: CGFloat = -BLOCK_H * 2
            camY = min(max(raw, minCamY), maxCamY)
            camTarget = camY
            setNeedsDisplay()
        default:
            break
        }
    }

    // MARK: Game Logic

    private func resetGame() {
        stack = [Block(x: 0, z: 0, w: BASE, d: BASE)]
        pieces = []; rings = []
        camY = 0; camTarget = 0; combo = 0
        hue0 = CGFloat.random(in: 0..<360)
        score = 0; comboMsg = nil
        lastComment = ""
        spawnMoving()
    }

    private func spawnMoving() {
        guard let top = stack.last else { return }
        let axis: MovingBlock.Axis = stack.count % 2 == 1 ? .x : .z
        moving = MovingBlock(x: top.x, z: top.z, w: top.w, d: top.d, axis: axis, t0: t, idx: stack.count)
    }

    private func blockHue(idx: Int) -> CGFloat {
        (hue0 + CGFloat(idx) * 7).truncatingRemainder(dividingBy: 360)
    }

    private func movingPos(mv: MovingBlock) -> CGFloat {
        // speed * 1000 vs JSX because CADisplayLink.timestamp is seconds, JSX uses milliseconds
        let speed: CGFloat = 2.1 * (1 + min(0.9, CGFloat(mv.idx) * 0.014))
        let base = mv.axis == .x ? stack.last!.x : stack.last!.z
        return base + AMPLITUDE * sin(CGFloat(t - mv.t0) * speed + .pi / 2)
    }

    private func drop() {
        guard let mv = moving, let top = stack.last else { return }
        let pos = movingPos(mv: mv)
        let topCenter = mv.axis == .x ? top.x : top.z
        let size = mv.axis == .x ? top.w : top.d
        let delta = pos - topCenter
        let overlap = size - abs(delta)
        let yLevel = CGFloat(stack.count) * BLOCK_H

        if overlap <= 0 {
            let px = mv.axis == .x ? pos : top.x
            let pz = mv.axis == .z ? pos : top.z
            pieces.append(FallingPiece(x: px, z: pz, w: mv.w, d: mv.d, y: yLevel, hue: blockHue(idx: mv.idx)))
            moving = nil
            overAt = t
            score = stack.count - 1
            if score > best {
                best = score
                UserDefaults.standard.set(best, forKey: BEST_SCORE_KEY)
            }
            lastComment = pickScoreComment(score: score)
            phase = .over
            AdsManager.shared.recordGameEnd()
            return
        }

        var nb: Block
        if abs(delta) <= PERFECT_TOL {
            combo += 1
            var w = mv.w, d = mv.d
            if combo >= 2 { w = min(BASE, w + 12); d = min(BASE, d + 12) }
            nb = Block(x: top.x, z: top.z, w: w, d: d)
            rings.append(Ring(x: top.x, z: top.z, y: yLevel))
            comboMsg = (n: combo, until: t + 1.0)
            AudioManager.shared.playSE("se_perfect")
        } else {
            combo = 0; comboMsg = nil
            let sign: CGFloat = delta > 0 ? 1 : -1
            let newCenter = topCenter + delta / 2
            let pieceCenter = newCenter + sign * size / 2
            nb = top
            if mv.axis == .x {
                nb.x = newCenter; nb.w = overlap
                pieces.append(FallingPiece(x: pieceCenter, z: top.z, w: abs(delta), d: top.d, y: yLevel, hue: blockHue(idx: mv.idx)))
            } else {
                nb.z = newCenter; nb.d = overlap
                pieces.append(FallingPiece(x: top.x, z: pieceCenter, w: top.w, d: abs(delta), y: yLevel, hue: blockHue(idx: mv.idx)))
            }
            AudioManager.shared.playSE("se_good")
        }

        stack.append(nb)
        camTarget = CGFloat(stack.count - 1) * BLOCK_H
        score = stack.count - 1
        spawnMoving()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        drawScene(ctx: ctx, rect: rect, viewing: phase == .viewingTower)
        drawHUD(ctx: ctx, rect: rect)
    }

    /// Renders sky, tower, pieces, and the moving block into the given context.
    /// When `viewing` is true, all blocks fit on screen and dynamic elements are hidden.
    private func drawScene(ctx: CGContext, rect: CGRect, viewing: Bool) {
        let W = rect.width, H = rect.height
        let baseS = min(W, 560) / 760
        let cx = W / 2
        let S = baseS
        let baseY = H * 0.62
        let camYUse = camY

        func proj(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
            CGPoint(
                x: cx + (x - z) * ISO_X * S,
                y: baseY + ((x + z) * 0.5 - (y - camYUse)) * S
            )
        }

        let palette = skyPalette(forCamY: camY)
        drawSky(ctx: ctx, W: W, H: H, palette: palette)
        drawStars(ctx: ctx, W: W, H: H, palette: palette)
        drawMoon(ctx: ctx, W: W, H: H, palette: palette)
        drawSun(ctx: ctx, W: W, H: H, palette: palette)

        // Tower
        let first = viewing ? 0 : max(0, stack.count - 14)
        for i in first..<stack.count {
            let b = stack[i]
            let yB: CGFloat = i == 0 ? -BLOCK_H * 4 : CGFloat(i) * BLOCK_H
            let h: CGFloat  = i == 0 ? BLOCK_H * 5  : BLOCK_H
            let alpha: CGFloat
            if viewing {
                alpha = 1
            } else {
                alpha = i < first + 3
                    ? min(1, CGFloat(i - first) / 3 + (i == stack.count - 1 ? 1 : 0.4))
                    : 1
            }
            drawBox(ctx: ctx, proj: proj, x: b.x, z: b.z, w: b.w, d: b.d, yBottom: yB, h: h, hue: blockHue(idx: i), alpha: alpha)
        }

        if !viewing {
            // Falling pieces
            for pc in pieces {
                drawBox(ctx: ctx, proj: proj, x: pc.x, z: pc.z, w: pc.w, d: pc.d, yBottom: pc.y, h: BLOCK_H, hue: pc.hue, alpha: pc.alpha)
            }

            // Perfect rings
            for ring in rings {
                let ce = proj(ring.x, ring.y, ring.z)
                let rx = ring.r * ISO_X, ry = ring.r * 0.5
                ctx.setStrokeColor(CGColor(red: 1, green: 240/255, blue: 200/255, alpha: ring.alpha))
                ctx.setLineWidth(2.5)
                ctx.strokeEllipse(in: CGRect(x: ce.x - rx, y: ce.y - ry, width: rx * 2, height: ry * 2))
            }

            // Moving block
            if let mv = moving, phase == .playing {
                let pos = movingPos(mv: mv)
                let bx = mv.axis == .x ? pos : stack.last!.x
                let bz = mv.axis == .z ? pos : stack.last!.z
                drawBox(ctx: ctx, proj: proj, x: bx, z: bz, w: mv.w, d: mv.d,
                        yBottom: CGFloat(stack.count) * BLOCK_H, h: BLOCK_H, hue: blockHue(idx: mv.idx), alpha: 1)
            }
        }
    }

    // MARK: Scene Elements

    private func drawSky(ctx: CGContext, W: CGFloat, H: CGFloat, palette: SkyPalette) {
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [palette.top, palette.mid, palette.bottom] as CFArray,
                                    locations: [0, 0.55, 1]) else { return }
        ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: H), options: [])
    }

    private func drawStars(ctx: CGContext, W: CGFloat, H: CGFloat, palette: SkyPalette) {
        guard palette.darkness > 0.05 else { return }
        let baseAlpha = min(1, (palette.darkness - 0.05) * 1.6)
        for star in STARS {
            let tw = 0.6 + 0.4 * sin(CGFloat(t) * 0.0012 + star.phase)
            ctx.setAlpha(baseAlpha * tw * 0.9)
            ctx.setFillColor(CGColor(red: 1, green: 247/255, blue: 232/255, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: star.x * W - star.size / 2, y: star.y * H - star.size / 2,
                                       width: star.size, height: star.size))
        }
        ctx.setAlpha(1)
    }

    private func drawMoon(ctx: CGContext, W: CGFloat, H: CGFloat, palette: SkyPalette) {
        guard palette.darkness > 0.25 else { return }
        let ma = min(1, (palette.darkness - 0.25) * 2.2)
        let mx = W * 0.8, my = H * 0.16, mr: CGFloat = 26
        let mr2 = mr * 0.86

        // Render the crescent in an offscreen transparent context. We fill the
        // outer disc with cream, then "punch out" the inner disc with .clear,
        // which yields a properly antialiased crescent with no leftover halo
        // ring around the original disc outline.
        let pad: CGFloat = 2
        let size = CGSize(width: mr * 2 + pad * 2, height: mr * 2 + pad * 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let crescent = renderer.image { rendererCtx in
            let c = rendererCtx.cgContext
            c.setFillColor(CGColor(red: 253/255, green: 243/255, blue: 216/255, alpha: 1))
            c.fillEllipse(in: CGRect(x: pad, y: pad, width: mr * 2, height: mr * 2))
            let innerCenterX = pad + mr - mr * 0.42
            let innerCenterY = pad + mr - mr * 0.18
            c.setBlendMode(.clear)
            c.fillEllipse(in: CGRect(
                x: innerCenterX - mr2,
                y: innerCenterY - mr2,
                width: mr2 * 2,
                height: mr2 * 2
            ))
        }

        // Pass `alpha:` explicitly — UIImage.draw(in:) ignores the context's
        // setAlpha, which made the moon pop in at full opacity instead of
        // fading up smoothly as the sky darkened.
        crescent.draw(
            in: CGRect(x: mx - mr - pad, y: my - mr - pad, width: size.width, height: size.height),
            blendMode: .normal,
            alpha: ma
        )
    }

    /// Sunrise disc for the dawn phase (visible roughly between 50 and 100 stories).
    private func drawSun(ctx: CGContext, W: CGFloat, H: CGFloat, palette: SkyPalette) {
        guard palette.dawnAmount > 0.1 else { return }
        let visible = min(1, (palette.dawnAmount - 0.1) * 1.4)
        let sx = W * 0.22, sy = H * 0.68, sr: CGFloat = 30
        if let halo = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 1, green: 225/255, blue: 175/255, alpha: 0.55 * visible),
                CGColor(red: 1, green: 200/255, blue: 150/255, alpha: 0)
            ] as CFArray,
            locations: [0, 1]
        ) {
            ctx.drawRadialGradient(halo,
                                   startCenter: CGPoint(x: sx, y: sy), startRadius: 0,
                                   endCenter: CGPoint(x: sx, y: sy), endRadius: sr * 3.6,
                                   options: [])
        }
        ctx.setAlpha(visible)
        ctx.setFillColor(CGColor(red: 1, green: 240/255, blue: 208/255, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2))
        ctx.setAlpha(1)
    }

    private func drawBox(
        ctx: CGContext, proj: (CGFloat, CGFloat, CGFloat) -> CGPoint,
        x: CGFloat, z: CGFloat, w: CGFloat, d: CGFloat,
        yBottom: CGFloat, h: CGFloat, hue: CGFloat, alpha: CGFloat
    ) {
        let yTop = yBottom + h
        let A  = proj(x - w/2, yTop,    z - d/2)
        let B  = proj(x + w/2, yTop,    z - d/2)
        let C  = proj(x + w/2, yTop,    z + d/2)
        let D  = proj(x - w/2, yTop,    z + d/2)
        let Bb = proj(x + w/2, yBottom, z - d/2)
        let Cb = proj(x + w/2, yBottom, z + d/2)
        let Db = proj(x - w/2, yBottom, z + d/2)
        let (top, right, left) = blockColors(hue: hue)

        ctx.saveGState()
        ctx.setAlpha(alpha)

        ctx.setFillColor(right)
        ctx.beginPath()
        ctx.move(to: B); ctx.addLine(to: C); ctx.addLine(to: Cb); ctx.addLine(to: Bb)
        ctx.closePath(); ctx.fillPath()

        ctx.setFillColor(left)
        ctx.beginPath()
        ctx.move(to: C); ctx.addLine(to: D); ctx.addLine(to: Db); ctx.addLine(to: Cb)
        ctx.closePath(); ctx.fillPath()

        ctx.setFillColor(top)
        ctx.beginPath()
        ctx.move(to: A); ctx.addLine(to: B); ctx.addLine(to: C); ctx.addLine(to: D)
        ctx.closePath(); ctx.fillPath()

        ctx.restoreGState()
    }

    // MARK: HUD

    private func drawHUD(ctx: CGContext, rect: CGRect) {
        let W = rect.width, H = rect.height
        let cream = UIColor(red: 1, green: 248/255, blue: 236/255, alpha: 1)

        // Reset tap zones each frame
        settingsBtnRect = .zero
        retryBtnRect = .zero
        menuBtnRect = .zero
        shareBtnRect = .zero
        viewTowerBtnRect = .zero
        closeBtnRect = .zero

        switch phase {
        case .title:
            ctx.setFillColor(UIColor(white: 0.06, alpha: 0.28).cgColor)
            ctx.fill(rect)

            let tSize = min(W * 0.2, 108)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: tSize, weight: .heavy),
                .foregroundColor: cream,
                .kern: tSize * 0.12
            ]
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: cream.withAlphaComponent(0.8), .kern: 7.0
            ]
            let capAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: cream.withAlphaComponent(0.88)
            ]

            let titleH = ("積み積み" as NSString).size(withAttributes: titleAttr).height
            let subH   = ("T S U M I  T S U M I" as NSString).size(withAttributes: subAttr).height
            let capH   = ("黄昏に、塔を積む。" as NSString).size(withAttributes: capAttr).height
            let groupH = titleH + 4 + subH + 18 + capH
            let groupY = (H - groupH) / 2 - H * 0.04

            drawCentered("積み積み",              attrs: titleAttr, in: W, at: groupY)
            drawCentered("T S U M I  T S U M I", attrs: subAttr,   in: W, at: groupY + titleH + 4)
            drawCentered("黄昏に、塔を積む。",    attrs: capAttr,   in: W, at: groupY + titleH + 4 + subH + 18)

            let tapAlpha = CGFloat(0.45 + 0.55 * abs(sin(CGFloat(t) * 2.2)))
            let tapAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: cream.withAlphaComponent(tapAlpha), .kern: 3.5
            ]
            drawCentered("タップしてはじめる", attrs: tapAttr, in: W, at: min(groupY + groupH + 56, H * 0.76))

            // Settings gear (top-right)
            drawSettingsButton(cream: cream, in: rect)

        case .playing:
            let scoreAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .light), .foregroundColor: cream
            ]
            let scoreH = ("\(score)" as NSString).size(withAttributes: scoreAttr).height
            drawCentered("\(score)", attrs: scoreAttr, in: W, at: H * 0.05)

            if let msg = comboMsg, t < msg.until {
                let elapsed = msg.until - t
                let a = CGFloat(elapsed < 0.3 ? elapsed / 0.3 : 1)
                let text = msg.n >= 2 ? "PERFECT ×\(msg.n)" : "PERFECT"
                let comboAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: UIColor(red: 1, green: 233/255, blue: 184/255, alpha: a),
                    .kern: 5.0
                ]
                drawCentered(text, attrs: comboAttr, in: W, at: H * 0.05 + scoreH + 6)
            }

        case .over:
            ctx.setFillColor(UIColor(white: 0.04, alpha: 0.38).cgColor)
            ctx.fill(rect)

            let hereAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: cream, .kern: 7.0
            ]
            let scoreAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .light), .foregroundColor: cream
            ]
            let bestAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: cream.withAlphaComponent(0.8), .kern: 2.8
            ]
            let commentAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: UIColor(red: 1, green: 233/255, blue: 184/255, alpha: 0.95),
                .kern: 3.0
            ]

            let bestText = "BEST \(best)"
            let hereH    = ("ここまで" as NSString).size(withAttributes: hereAttr).height
            let scoreH   = ("\(score)" as NSString).size(withAttributes: scoreAttr).height
            let bestH    = (bestText as NSString).size(withAttributes: bestAttr).height
            let commentText = lastComment.isEmpty ? pickScoreComment(score: score) : lastComment
            let commentH = (commentText as NSString).size(withAttributes: commentAttr).height
            let groupH   = hereH + scoreH + bestH + 18 + commentH
            let groupY   = (H - groupH) / 2 - H * 0.10

            drawCentered("ここまで",  attrs: hereAttr,    in: W, at: groupY)
            drawCentered("\(score)",  attrs: scoreAttr,   in: W, at: groupY + hereH)
            drawCentered(bestText,    attrs: bestAttr,    in: W, at: groupY + hereH + scoreH)
            drawCentered(commentText, attrs: commentAttr, in: W, at: groupY + hereH + scoreH + bestH + 18)

            drawOverButtons(cream: cream, in: rect)

        case .viewingTower:
            drawTowerViewingHUD(cream: cream, in: rect)
        }
    }

    private func drawSettingsButton(cream: UIColor, in rect: CGRect) {
        let safe = safeAreaInsets
        let size: CGFloat = 30
        let x = rect.width - size - 18
        let y = max(safe.top + 12, 20)
        let iconRect = CGRect(x: x, y: y, width: size, height: size)

        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
        if let img = UIImage(systemName: "gearshape.fill", withConfiguration: cfg)?
            .withTintColor(cream.withAlphaComponent(0.85), renderingMode: .alwaysOriginal) {
            img.draw(in: iconRect)
        }
        // Expanded hit area
        settingsBtnRect = iconRect.insetBy(dx: -14, dy: -14)
    }

    private func drawOverButtons(cream: UIColor, in rect: CGRect) {
        let W = rect.width, H = rect.height
        let safe = safeAreaInsets
        // Lift buttons above the AdMob banner (~50pt) that sits at the safe-area bottom.
        let bannerInset: CGFloat = 58
        let bottomInset = max(safe.bottom + 16, 32) + bannerInset
        let bw = min(W - 64, 280)
        let bh: CGFloat = 46
        let gap: CGFloat = 8

        let totalH = bh * 4 + gap * 3
        var y = H - bottomInset - totalH

        let retry = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "もう一度", rect: retry, cream: cream, filled: true)
        retryBtnRect = retry
        y += bh + gap

        let viewTower = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "塔をみる", rect: viewTower, cream: cream, filled: false)
        viewTowerBtnRect = viewTower
        y += bh + gap

        let share = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "シェアする", rect: share, cream: cream, filled: false)
        shareBtnRect = share
        y += bh + gap

        let menu = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "メインメニュー", rect: menu, cream: cream, filled: false)
        menuBtnRect = menu
    }

    private func drawTowerViewingHUD(cream: UIColor, in rect: CGRect) {
        let W = rect.width
        let safe = safeAreaInsets

        // Header label: "あなたの塔  /  N 段"
        let headerY = max(safe.top + 18, 28)
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: cream.withAlphaComponent(0.8),
            .kern: 5.0
        ]
        let scoreAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .light),
            .foregroundColor: cream
        ]
        let hintAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: cream.withAlphaComponent(0.55),
            .kern: 3.0
        ]
        drawCentered("あなたの塔", attrs: labelAttr, in: W, at: headerY)
        let labelH = ("あなたの塔" as NSString).size(withAttributes: labelAttr).height
        drawCentered("\(score) 段", attrs: scoreAttr, in: W, at: headerY + labelH + 2)
        let scoreH = ("\(score) 段" as NSString).size(withAttributes: scoreAttr).height
        drawCentered("上下にスワイプして見る", attrs: hintAttr, in: W, at: headerY + labelH + 2 + scoreH + 6)

        // Close button at bottom (lifted above banner).
        let bannerInset: CGFloat = 58
        let bottomInset = max(safe.bottom + 16, 32) + bannerInset
        let bw = min(W - 64, 280)
        let bh: CGFloat = 46
        let close = CGRect(x: (W - bw) / 2, y: rect.height - bottomInset - bh, width: bw, height: bh)
        drawButton(label: "閉じる", rect: close, cream: cream, filled: false)
        closeBtnRect = close
    }

    // MARK: Share Image

    /// Renders a 1080x1080 share image: white border around a rounded panel
    /// containing the full tower scene, with the score and brand wordmark below.
    func makeShareImage(score: Int) -> UIImage {
        let canvasSize: CGFloat = 1080
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize))
        return renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext

            // White outer background.
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

            let outerMargin: CGFloat = 56
            let panel = CGRect(
                x: outerMargin, y: outerMargin,
                width: canvasSize - outerMargin * 2,
                height: canvasSize - outerMargin * 2
            )
            let panelPath = UIBezierPath(roundedRect: panel, cornerRadius: 36)

            // Soft shadow under the panel.
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 24,
                          color: UIColor(white: 0, alpha: 0.18).cgColor)
            ctx.setFillColor(UIColor.white.cgColor)
            panelPath.fill()
            ctx.restoreGState()

            // Render the scene clipped to the panel.
            ctx.saveGState()
            panelPath.addClip()
            ctx.translateBy(x: panel.minX, y: panel.minY)
            drawShareScene(ctx: ctx, size: panel.size, score: score)
            ctx.restoreGState()
        }
    }

    private func drawShareScene(ctx: CGContext, size: CGSize, score: Int) {
        let W = size.width, H = size.height
        let towerH = CGFloat(max(stack.count, 1)) * BLOCK_H

        // Compact text band at the bottom so the tower can dominate the panel.
        let textBandH = H * 0.17
        let sceneH = H - textBandH

        // Width and height fits; the projected tower width is 2 * BASE * ISO_X * S.
        let widthLimit = (W * 0.84) / (2 * BASE * ISO_X)
        let availH = sceneH * 0.94
        let S = min(widthLimit, availH / towerH)

        // Center the tower vertically inside the scene area.
        let towerSpan = towerH * S
        let towerTopY = (sceneH - towerSpan) / 2
        let baseY = towerTopY + towerSpan
        let cx = W / 2

        // Sky reflects the player's final height so 50+ shows dawn, 100+ deep night.
        let palette = skyPalette(forCamY: CGFloat(max(stack.count - 1, 0)) * BLOCK_H)

        func proj(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
            CGPoint(
                x: cx + (x - z) * ISO_X * S,
                y: baseY + ((x + z) * 0.5 - y) * S
            )
        }

        drawSky(ctx: ctx, W: W, H: H, palette: palette)
        drawStars(ctx: ctx, W: W, H: H, palette: palette)
        drawMoon(ctx: ctx, W: W, H: H, palette: palette)
        drawSun(ctx: ctx, W: W, H: H, palette: palette)

        for i in 0..<stack.count {
            let b = stack[i]
            let yB: CGFloat = i == 0 ? -BLOCK_H * 4 : CGFloat(i) * BLOCK_H
            let h: CGFloat  = i == 0 ? BLOCK_H * 5  : BLOCK_H
            drawBox(ctx: ctx, proj: proj, x: b.x, z: b.z, w: b.w, d: b.d,
                    yBottom: yB, h: h, hue: blockHue(idx: i), alpha: 1)
        }

        // Soft gradient under the text band so the wordmark stays legible.
        let bandRect = CGRect(x: 0, y: H - textBandH, width: W, height: textBandH)
        let gradColors = [
            UIColor(white: 0, alpha: 0).cgColor,
            UIColor(white: 0, alpha: 0.5).cgColor
        ] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: gradColors, locations: [0, 1]) {
            ctx.drawLinearGradient(grad,
                                   start: CGPoint(x: 0, y: bandRect.minY),
                                   end: CGPoint(x: 0, y: bandRect.maxY),
                                   options: [])
        }

        let cream = UIColor(red: 1, green: 248/255, blue: 236/255, alpha: 1)
        let brandAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: cream.withAlphaComponent(0.9),
            .kern: 8.0
        ]
        let scoreAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 96, weight: .light),
            .foregroundColor: cream
        ]
        let suffixAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .regular),
            .foregroundColor: cream.withAlphaComponent(0.92)
        ]

        let brand = "T S U M I  T S U M I"
        let scoreText = "\(score)"
        let suffix = "段"
        let brandSize = (brand as NSString).size(withAttributes: brandAttr)
        let scoreSize = (scoreText as NSString).size(withAttributes: scoreAttr)
        let suffixSize = (suffix as NSString).size(withAttributes: suffixAttr)

        let scoreLineW = scoreSize.width + 12 + suffixSize.width
        let blockH = brandSize.height + 4 + scoreSize.height
        let blockY = bandRect.minY + (textBandH - blockH) / 2

        (brand as NSString).draw(
            at: CGPoint(x: (W - brandSize.width) / 2, y: blockY),
            withAttributes: brandAttr
        )

        let scoreX = (W - scoreLineW) / 2
        let scoreY = blockY + brandSize.height + 4
        (scoreText as NSString).draw(
            at: CGPoint(x: scoreX, y: scoreY),
            withAttributes: scoreAttr
        )
        let suffixY = scoreY + scoreSize.height - suffixSize.height - 12
        (suffix as NSString).draw(
            at: CGPoint(x: scoreX + scoreSize.width + 12, y: suffixY),
            withAttributes: suffixAttr
        )
    }

    private func drawButton(label: String, rect: CGRect, cream: UIColor, filled: Bool) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        if filled {
            ctx.setFillColor(cream.withAlphaComponent(0.92).cgColor)
            path.fill()
        } else {
            ctx.setStrokeColor(cream.withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(1.2)
            path.stroke()
        }
        let textColor = filled
            ? UIColor(red: 27/255, green: 34/255, blue: 71/255, alpha: 1)
            : cream
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: textColor,
            .kern: 4.0
        ]
        let sz = (label as NSString).size(withAttributes: attrs)
        (label as NSString).draw(
            at: CGPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2),
            withAttributes: attrs
        )
    }

    private func drawCentered(_ text: String, attrs: [NSAttributedString.Key: Any], in width: CGFloat, at y: CGFloat) {
        let str = text as NSString
        let sz = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: (width - sz.width) / 2, y: y), withAttributes: attrs)
    }

    // MARK: Color Helpers

    private func blockColors(hue: CGFloat) -> (top: CGColor, right: CGColor, left: CGColor) {
        (hsl(hue, 0.52, 0.64), hsl(hue, 0.50, 0.49), hsl(hue, 0.52, 0.40))
    }

    private func hsl(_ h: CGFloat, _ s: CGFloat, _ l: CGFloat) -> CGColor {
        let hNorm = h / 360
        let c = (1 - abs(2 * l - 1)) * s
        let sector = hNorm * 6
        let x = c * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        switch Int(sector) {
        case 0: r = c; g = x
        case 1: r = x; g = c
        case 2: g = c; b = x
        case 3: g = x; b = c
        case 4: r = x; b = c
        default: r = c; b = x
        }
        return CGColor(red: r + m, green: g + m, blue: b + m, alpha: 1)
    }
}

// MARK: - Gesture Delegate

extension GameView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let p = touch.location(in: self)
        // Block taps that land inside a modal overlay so the overlay (and only the overlay) handles them.
        for sub in subviews where sub is SettingsOverlay {
            if sub.frame.contains(p) { return false }
        }
        // Pan only matters while the player is scrolling through their tower.
        if gestureRecognizer is UIPanGestureRecognizer && phase != .viewingTower {
            return false
        }
        return true
    }
}
