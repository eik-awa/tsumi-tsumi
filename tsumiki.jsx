import React, { useRef, useEffect, useState } from "react";

// ---- 定数 ----
const BASE = 240;          // ブロックの初期サイズ(平面)
const BLOCK_H = 52;        // ブロックの高さ(ワールド単位)
const PERFECT_TOL = 8;     // パーフェクト判定の許容幅
const AMPLITUDE = 340;     // 往復移動の振幅
const ISO_X = Math.cos(Math.PI / 6); // ≈0.866

// 空の色(黄昏 → 深夜)
const SKY_DUSK = [[71, 48, 102], [183, 92, 126], [242, 161, 124]];
const SKY_NIGHT = [[9, 13, 38], [27, 34, 71], [56, 50, 102]];

const lerp = (a, b, t) => a + (b - a) * t;
const lerpColor = (c1, c2, t) =>
  `rgb(${Math.round(lerp(c1[0], c2[0], t))},${Math.round(
    lerp(c1[1], c2[1], t)
  )},${Math.round(lerp(c1[2], c2[2], t))})`;

// 固定の擬似乱数(星の配置用)
const STARS = Array.from({ length: 90 }, (_, i) => {
  const s = Math.sin(i * 127.1) * 43758.5453;
  const r = s - Math.floor(s);
  const s2 = Math.sin(i * 311.7) * 12543.853;
  const r2 = s2 - Math.floor(s2);
  return { x: r, y: r2 * 0.75, size: 0.6 + (r * r2) * 1.6, ph: r2 * 6.28 };
});

export default function Tsumiki() {
  const canvasRef = useRef(null);
  const wrapRef = useRef(null);
  const [phase, setPhase] = useState("title"); // title | playing | over
  const [score, setScore] = useState(0);
  const [best, setBest] = useState(0);
  const [comboMsg, setComboMsg] = useState(null);

  const g = useRef({
    stack: [],
    moving: null,
    pieces: [],
    rings: [],
    camY: 0,
    camTarget: 0,
    t: 0,
    phase: "title",
    combo: 0,
    hue0: Math.random() * 360,
    overAt: 0,
    reduced: false,
  });

  // フェーズをrefにも同期
  useEffect(() => {
    g.current.phase = phase;
  }, [phase]);

  const resetGame = () => {
    const s = g.current;
    s.stack = [{ x: 0, z: 0, w: BASE, d: BASE }];
    s.pieces = [];
    s.rings = [];
    s.camY = 0;
    s.camTarget = 0;
    s.combo = 0;
    s.hue0 = Math.random() * 360;
    spawnMoving();
    setScore(0);
    setComboMsg(null);
  };

  const spawnMoving = () => {
    const s = g.current;
    const top = s.stack[s.stack.length - 1];
    const axis = s.stack.length % 2 === 1 ? "x" : "z";
    s.moving = {
      x: top.x,
      z: top.z,
      w: top.w,
      d: top.d,
      axis,
      t0: s.t,
      idx: s.stack.length,
    };
  };

  const blockHue = (idx) => (g.current.hue0 + idx * 7) % 360;

  const drop = () => {
    const s = g.current;
    if (!s.moving) return;
    const mv = s.moving;
    const top = s.stack[s.stack.length - 1];
    const axis = mv.axis;
    const pos = movingPos(mv, s.t);
    const delta = pos - top[axis];
    const size = axis === "x" ? top.w : top.d;
    const overlap = size - Math.abs(delta);
    const y = s.stack.length * BLOCK_H;

    if (overlap <= 0) {
      // 完全に外した → ブロックごと落下、ゲームオーバー
      s.pieces.push({
        x: axis === "x" ? pos : top.x,
        z: axis === "z" ? pos : top.z,
        w: mv.w,
        d: mv.d,
        y,
        vy: 0,
        hue: blockHue(mv.idx),
        alpha: 1,
      });
      s.moving = null;
      s.overAt = performance.now();
      setBest((b) => Math.max(b, s.stack.length - 1));
      setPhase("over");
      return;
    }

    let nb;
    if (Math.abs(delta) <= PERFECT_TOL) {
      // パーフェクト:吸着+コンボで少し回復
      s.combo += 1;
      let w = mv.w, d = mv.d;
      if (s.combo >= 2) {
        w = Math.min(BASE, w + 12);
        d = Math.min(BASE, d + 12);
      }
      nb = { x: top.x, z: top.z, w, d };
      s.rings.push({ x: top.x, z: top.z, y: y, r: 0, alpha: 0.9 });
      setComboMsg({ n: s.combo, key: Date.now() });
    } else {
      // はみ出しをカット
      s.combo = 0;
      const newCenter = top[axis] + delta / 2;
      const pieceCenter =
        newCenter + Math.sign(delta) * (overlap + Math.abs(delta)) / 2;
      nb = { ...top };
      nb[axis] = newCenter;
      if (axis === "x") nb.w = overlap;
      else nb.d = overlap;
      const piece = {
        x: axis === "x" ? pieceCenter : top.x,
        z: axis === "z" ? pieceCenter : top.z,
        w: axis === "x" ? Math.abs(delta) : top.w,
        d: axis === "z" ? Math.abs(delta) : top.d,
        y,
        vy: 0,
        hue: blockHue(mv.idx),
        alpha: 1,
      };
      s.pieces.push(piece);
      setComboMsg(null);
    }
    s.stack.push(nb);
    s.camTarget = (s.stack.length - 1) * BLOCK_H;
    setScore(s.stack.length - 1);
    spawnMoving();
  };

  const movingPos = (mv, t) => {
    const speed = 0.0021 * (1 + Math.min(0.9, mv.idx * 0.014));
    const base = g.current.stack[g.current.stack.length - 1][mv.axis];
    return base + AMPLITUDE * Math.sin((t - mv.t0) * speed + Math.PI / 2);
  };

  // ---- メインループ & 描画 ----
  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");
    let raf;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    g.current.reduced = mq.matches;

    const resize = () => {
      const dpr = Math.min(2, window.devicePixelRatio || 1);
      const r = wrapRef.current.getBoundingClientRect();
      canvas.width = r.width * dpr;
      canvas.height = r.height * dpr;
      canvas.style.width = r.width + "px";
      canvas.style.height = r.height + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    window.addEventListener("resize", resize);

    const faceColors = (hue) => ({
      top: `hsl(${hue} 52% 64%)`,
      right: `hsl(${hue} 50% 49%)`,
      left: `hsl(${hue} 52% 40%)`,
    });

    const loop = (now) => {
      const s = g.current;
      s.t = now;
      const W = canvas.clientWidth;
      const H = canvas.clientHeight;
      const S = Math.min(W, 560) / 760; // スケール
      const cx = W / 2;
      const baseY = H * 0.62;

      s.camY += (s.camTarget - s.camY) * 0.08;

      const proj = (x, y, z) => ({
        sx: cx + (x - z) * ISO_X * S,
        sy: baseY + ((x + z) * 0.5 - (y - s.camY)) * S,
      });

      // --- 空 ---
      const p = Math.min(1, s.camY / (BLOCK_H * 42));
      const grad = ctx.createLinearGradient(0, 0, 0, H);
      grad.addColorStop(0, lerpColor(SKY_DUSK[0], SKY_NIGHT[0], p));
      grad.addColorStop(0.55, lerpColor(SKY_DUSK[1], SKY_NIGHT[1], p));
      grad.addColorStop(1, lerpColor(SKY_DUSK[2], SKY_NIGHT[2], p));
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, W, H);

      // 星(高く積むほど現れる)
      if (p > 0.05) {
        for (const st of STARS) {
          const tw = s.reduced ? 1 : 0.6 + 0.4 * Math.sin(now * 0.0012 + st.ph);
          ctx.globalAlpha = Math.min(1, (p - 0.05) * 1.6) * tw * 0.9;
          ctx.fillStyle = "#fff7e8";
          ctx.beginPath();
          ctx.arc(st.x * W, st.y * H, st.size, 0, 6.28);
          ctx.fill();
        }
        ctx.globalAlpha = 1;
      }
      // 三日月
      if (p > 0.25) {
        const ma = Math.min(1, (p - 0.25) * 2.2);
        ctx.globalAlpha = ma;
        const mx = W * 0.8, my = H * 0.16, mr = 26;
        ctx.fillStyle = "#fdf3d8";
        ctx.beginPath();
        ctx.arc(mx, my, mr, 0, 6.28);
        ctx.fill();
        ctx.fillStyle = lerpColor(SKY_DUSK[0], SKY_NIGHT[0], p);
        ctx.beginPath();
        ctx.arc(mx - mr * 0.42, my - mr * 0.18, mr * 0.86, 0, 6.28);
        ctx.fill();
        ctx.globalAlpha = 1;
      }

      // --- ブロック描画関数 ---
      const drawBox = (x, z, w, d, yBottom, h, hue, alpha = 1) => {
        const c = faceColors(hue);
        const yTop = yBottom + h;
        const A = proj(x - w / 2, yTop, z - d / 2);
        const B = proj(x + w / 2, yTop, z - d / 2);
        const C = proj(x + w / 2, yTop, z + d / 2);
        const D = proj(x - w / 2, yTop, z + d / 2);
        const Bb = proj(x + w / 2, yBottom, z - d / 2);
        const Cb = proj(x + w / 2, yBottom, z + d / 2);
        const Db = proj(x - w / 2, yBottom, z + d / 2);
        ctx.globalAlpha = alpha;
        // 右面 (+x)
        ctx.fillStyle = c.right;
        ctx.beginPath();
        ctx.moveTo(B.sx, B.sy); ctx.lineTo(C.sx, C.sy);
        ctx.lineTo(Cb.sx, Cb.sy); ctx.lineTo(Bb.sx, Bb.sy);
        ctx.closePath(); ctx.fill();
        // 左面 (+z)
        ctx.fillStyle = c.left;
        ctx.beginPath();
        ctx.moveTo(C.sx, C.sy); ctx.lineTo(D.sx, D.sy);
        ctx.lineTo(Db.sx, Db.sy); ctx.lineTo(Cb.sx, Cb.sy);
        ctx.closePath(); ctx.fill();
        // 上面
        ctx.fillStyle = c.top;
        ctx.beginPath();
        ctx.moveTo(A.sx, A.sy); ctx.lineTo(B.sx, B.sy);
        ctx.lineTo(C.sx, C.sy); ctx.lineTo(D.sx, D.sy);
        ctx.closePath(); ctx.fill();
        ctx.globalAlpha = 1;
      };

      // --- 塔(直近のブロックのみ・下は霞に溶ける) ---
      const stk = s.stack;
      const first = Math.max(0, stk.length - 14);
      for (let i = first; i < stk.length; i++) {
        const b = stk[i];
        const yB = i === 0 ? -BLOCK_H * 4 : i * BLOCK_H;
        const h = i === 0 ? BLOCK_H * 5 : BLOCK_H;
        const fade = Math.min(1, (i - first) / 3 + (i === stk.length - 1 ? 1 : 0.4));
        drawBox(b.x, b.z, b.w, b.d, yB, h, blockHue(i), i < first + 3 ? fade : 1);
      }

      // --- 落下する破片 ---
      for (const pc of s.pieces) {
        pc.vy += 0.5;
        pc.y -= pc.vy;
        pc.alpha = Math.max(0, pc.alpha - 0.006);
        drawBox(pc.x, pc.z, pc.w, pc.d, pc.y, BLOCK_H, pc.hue, pc.alpha);
      }
      s.pieces = s.pieces.filter((pc) => pc.alpha > 0.02 && pc.y > s.camY - 2000);

      // --- パーフェクトの輪 ---
      for (const r of s.rings) {
        r.r += s.reduced ? 22 : 9;
        r.alpha -= 0.035;
        if (r.alpha <= 0) continue;
        const ce = proj(r.x, r.y, r.z);
        ctx.strokeStyle = `rgba(255,240,200,${r.alpha})`;
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.ellipse(ce.sx, ce.sy, r.r * ISO_X, r.r * 0.5, 0, 0, 6.28);
        ctx.stroke();
      }
      s.rings = s.rings.filter((r) => r.alpha > 0);

      // --- 移動中ブロック ---
      if (s.moving && s.phase === "playing") {
        const mv = s.moving;
        const pos = movingPos(mv, now);
        const x = mv.axis === "x" ? pos : s.stack[s.stack.length - 1].x;
        const z = mv.axis === "z" ? pos : s.stack[s.stack.length - 1].z;
        drawBox(x, z, mv.w, mv.d, s.stack.length * BLOCK_H, BLOCK_H, blockHue(mv.idx));
      }

      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    const onKey = (e) => {
      if (e.code === "Space") {
        e.preventDefault();
        handleTap();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      window.removeEventListener("keydown", onKey);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleTap = () => {
    const s = g.current;
    if (s.phase === "title") {
      resetGame();
      setPhase("playing");
    } else if (s.phase === "playing") {
      drop();
    } else if (s.phase === "over") {
      if (performance.now() - s.overAt < 600) return; // 誤タップ防止
      resetGame();
      setPhase("playing");
    }
  };

  return (
    <div
      ref={wrapRef}
      onPointerDown={handleTap}
      style={{
        position: "fixed",
        inset: 0,
        overflow: "hidden",
        userSelect: "none",
        touchAction: "manipulation",
        cursor: "pointer",
        fontFamily: "'Outfit', sans-serif",
        background: "#473066",
      }}
    >
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Shippori+Mincho+B1:wght@700;800&family=Outfit:wght@300;500;700&display=swap');
        @keyframes rise { from { opacity:0; transform: translateY(14px);} to { opacity:1; transform:none;} }
        @keyframes pop { 0% { transform: scale(.6); opacity:0;} 40%{ transform: scale(1.12); opacity:1;} 100%{ transform: scale(1); opacity:0;} }
        @keyframes blink { 0%,100% { opacity:.45;} 50% { opacity:1;} }
        @media (prefers-reduced-motion: reduce) {
          .anim { animation: none !important; opacity: 1 !important; }
        }
      `}</style>

      <canvas ref={canvasRef} style={{ display: "block", position: "absolute", inset: 0 }} />

      {/* スコア */}
      {phase === "playing" && (
        <div
          style={{
            position: "absolute", top: "5%", left: 0, right: 0,
            textAlign: "center", color: "#fff8ec", pointerEvents: "none",
          }}
        >
          <div style={{ fontSize: 72, fontWeight: 300, lineHeight: 1, textShadow: "0 2px 18px rgba(0,0,0,.25)" }}>
            {score}
          </div>
          {comboMsg && (
            <div
              key={comboMsg.key}
              className="anim"
              style={{
                marginTop: 6, fontSize: 15, letterSpacing: "0.35em",
                fontWeight: 700, color: "#ffe9b8",
                animation: "pop 1s ease-out forwards",
              }}
            >
              PERFECT{comboMsg.n >= 2 ? ` ×${comboMsg.n}` : ""}
            </div>
          )}
        </div>
      )}

      {/* タイトル */}
      {phase === "title" && (
        <div
          className="anim"
          style={{
            position: "absolute", inset: 0, display: "flex", flexDirection: "column",
            alignItems: "center", justifyContent: "center", color: "#fff8ec",
            background: "linear-gradient(rgba(20,12,40,.18), rgba(20,12,40,.42))",
            animation: "rise .8s ease-out", pointerEvents: "none",
          }}
        >
          <div style={{ fontFamily: "'Shippori Mincho B1', serif", fontSize: "min(20vw, 108px)", fontWeight: 800, letterSpacing: "0.12em", textShadow: "0 4px 30px rgba(0,0,0,.35)" }}>
            積み木
          </div>
          <div style={{ letterSpacing: "0.6em", fontSize: 14, fontWeight: 500, marginTop: 4, opacity: 0.85, textIndent: "0.6em" }}>
            T S U M I K I
          </div>
          <div style={{ marginTop: 18, fontFamily: "'Shippori Mincho B1', serif", fontSize: 16, opacity: 0.9 }}>
            黄昏に、塔を積む。
          </div>
          <div className="anim" style={{ marginTop: 56, fontSize: 14, letterSpacing: "0.25em", animation: "blink 2.2s infinite" }}>
            タップしてはじめる
          </div>
        </div>
      )}

      {/* ゲームオーバー */}
      {phase === "over" && (
        <div
          className="anim"
          style={{
            position: "absolute", inset: 0, display: "flex", flexDirection: "column",
            alignItems: "center", justifyContent: "center", color: "#fff8ec",
            background: "linear-gradient(rgba(10,8,28,.3), rgba(10,8,28,.55))",
            animation: "rise .6s ease-out", pointerEvents: "none",
          }}
        >
          <div style={{ fontFamily: "'Shippori Mincho B1', serif", fontSize: 26, letterSpacing: "0.3em", textIndent: "0.3em" }}>
            ここまで
          </div>
          <div style={{ fontSize: 96, fontWeight: 300, lineHeight: 1.15 }}>{score}</div>
          <div style={{ fontSize: 14, letterSpacing: "0.2em", opacity: 0.8 }}>
            BEST {Math.max(best, score)}
          </div>
          <div className="anim" style={{ marginTop: 48, fontSize: 14, letterSpacing: "0.25em", animation: "blink 2.2s infinite" }}>
            タップでもう一度
          </div>
        </div>
      )}
    </div>
  );
}
