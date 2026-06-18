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

private enum GamePhase { case title, playing, over }

// MARK: - Delegate

protocol GameViewDelegate: AnyObject {
    func gameViewDidRequestSettings()
    func gameViewDidRequestShare(score: Int)
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

    // Tap zones (set during draw, consumed in handleTap)
    private var settingsBtnRect: CGRect = .zero
    private var retryBtnRect: CGRect = .zero
    private var menuBtnRect: CGRect = .zero
    private var shareBtnRect: CGRect = .zero

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
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
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
        camY += (camTarget - camY) * 0.08
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
                delegate?.gameViewDidRequestShare(score: score)
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
        }
    }

    // MARK: Game Logic

    private func resetGame() {
        stack = [Block(x: 0, z: 0, w: BASE, d: BASE)]
        pieces = []; rings = []
        camY = 0; camTarget = 0; combo = 0
        hue0 = CGFloat.random(in: 0..<360)
        score = 0; comboMsg = nil
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
            best = max(best, stack.count - 1)
            score = stack.count - 1
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

        let W = rect.width, H = rect.height
        let S = min(W, 560) / 760
        let cx = W / 2, baseY = H * 0.62
        let skyP = min(1, camY / (BLOCK_H * 42))

        func proj(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
            CGPoint(
                x: cx + (x - z) * ISO_X * S,
                y: baseY + ((x + z) * 0.5 - (y - camY)) * S
            )
        }

        drawSky(ctx: ctx, W: W, H: H, p: skyP)
        drawStars(ctx: ctx, W: W, H: H, p: skyP)
        drawMoon(ctx: ctx, W: W, H: H, p: skyP)

        // Tower
        let first = max(0, stack.count - 14)
        for i in first..<stack.count {
            let b = stack[i]
            let yB: CGFloat = i == 0 ? -BLOCK_H * 4 : CGFloat(i) * BLOCK_H
            let h: CGFloat  = i == 0 ? BLOCK_H * 5  : BLOCK_H
            let alpha: CGFloat = i < first + 3
                ? min(1, CGFloat(i - first) / 3 + (i == stack.count - 1 ? 1 : 0.4))
                : 1
            drawBox(ctx: ctx, proj: proj, x: b.x, z: b.z, w: b.w, d: b.d, yBottom: yB, h: h, hue: blockHue(idx: i), alpha: alpha)
        }

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

        drawHUD(ctx: ctx, rect: rect)
    }

    // MARK: Scene Elements

    private func drawSky(ctx: CGContext, W: CGFloat, H: CGFloat, p: CGFloat) {
        let c0 = lerpColor(SKY_DUSK[0], SKY_NIGHT[0], t: p)
        let c1 = lerpColor(SKY_DUSK[1], SKY_NIGHT[1], t: p)
        let c2 = lerpColor(SKY_DUSK[2], SKY_NIGHT[2], t: p)
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [c0, c1, c2] as CFArray,
                                    locations: [0, 0.55, 1]) else { return }
        ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: H), options: [])
    }

    private func drawStars(ctx: CGContext, W: CGFloat, H: CGFloat, p: CGFloat) {
        guard p > 0.05 else { return }
        let baseAlpha = min(1, (p - 0.05) * 1.6)
        for star in STARS {
            let tw = 0.6 + 0.4 * sin(CGFloat(t) * 0.0012 + star.phase)
            ctx.setAlpha(baseAlpha * tw * 0.9)
            ctx.setFillColor(CGColor(red: 1, green: 247/255, blue: 232/255, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: star.x * W - star.size / 2, y: star.y * H - star.size / 2,
                                       width: star.size, height: star.size))
        }
        ctx.setAlpha(1)
    }

    private func drawMoon(ctx: CGContext, W: CGFloat, H: CGFloat, p: CGFloat) {
        guard p > 0.25 else { return }
        let ma = min(1, (p - 0.25) * 2.2)
        ctx.setAlpha(ma)
        let mx = W * 0.8, my = H * 0.16, mr: CGFloat = 26
        ctx.setFillColor(CGColor(red: 253/255, green: 243/255, blue: 216/255, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: mx - mr, y: my - mr, width: mr * 2, height: mr * 2))
        let mr2 = mr * 0.86
        ctx.setFillColor(lerpColor(SKY_DUSK[0], SKY_NIGHT[0], t: p))
        ctx.fillEllipse(in: CGRect(x: mx - mr * 0.42 - mr2, y: my - mr * 0.18 - mr2, width: mr2 * 2, height: mr2 * 2))
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

            let hereH    = ("ここまで" as NSString).size(withAttributes: hereAttr).height
            let scoreH   = ("\(score)" as NSString).size(withAttributes: scoreAttr).height
            let bestH    = ("BEST \(max(best, score))" as NSString).size(withAttributes: bestAttr).height
            let commentH = (scoreComment(score) as NSString).size(withAttributes: commentAttr).height
            let groupH   = hereH + scoreH + bestH + 18 + commentH
            let groupY   = (H - groupH) / 2 - H * 0.10

            drawCentered("ここまで",                attrs: hereAttr,    in: W, at: groupY)
            drawCentered("\(score)",                 attrs: scoreAttr,   in: W, at: groupY + hereH)
            drawCentered("BEST \(max(best, score))", attrs: bestAttr,    in: W, at: groupY + hereH + scoreH)
            drawCentered(scoreComment(score),        attrs: commentAttr, in: W, at: groupY + hereH + scoreH + bestH + 18)

            drawOverButtons(cream: cream, in: rect)
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
        let bh: CGFloat = 48
        let gap: CGFloat = 10

        let totalH = bh * 3 + gap * 2
        var y = H - bottomInset - totalH

        let retry = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "もう一度", rect: retry, cream: cream, filled: true)
        retryBtnRect = retry
        y += bh + gap

        let menu = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "メインメニュー", rect: menu, cream: cream, filled: false)
        menuBtnRect = menu
        y += bh + gap

        let share = CGRect(x: (W - bw) / 2, y: y, width: bw, height: bh)
        drawButton(label: "シェアする", rect: share, cream: cream, filled: false)
        shareBtnRect = share
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

    private func scoreComment(_ s: Int) -> String {
        switch s {
        case 0:       return "もう一度挑戦！"
        case 1...2:   return "あとちょっと"
        case 3...5:   return "いいかんじ"
        case 6...9:   return "うまいね！"
        case 10...14: return "すごい！"
        case 15...19: return "ほんとに上手"
        case 20...29: return "見事な腕前！"
        default:      return "あなた、天才かも"
        }
    }

    // MARK: Color Helpers

    private func lerpColor(
        _ c1: (CGFloat, CGFloat, CGFloat),
        _ c2: (CGFloat, CGFloat, CGFloat),
        t: CGFloat
    ) -> CGColor {
        CGColor(red:   c1.0 + (c2.0 - c1.0) * t,
                green: c1.1 + (c2.1 - c1.1) * t,
                blue:  c1.2 + (c2.2 - c1.2) * t,
                alpha: 1)
    }

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
        return true
    }
}
