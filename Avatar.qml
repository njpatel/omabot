import QtQuick

// A Grok Bot avatar: the bot's own shape and colour, with eyes whose
// expression carries its state. The 18 shape names and the colour palette come
// from the app bundle, so a bot looks the same here as it does in the app; the
// expressions are ours, because the app stores none - it is the cheapest way to
// read "this one wants you" from the corner of your eye.
Item {
  id: root

  property string shape: "squircle"
  property color fill: "#777777"
  property color eyeColor: "#111111"
  // calm · working (thinking about your last message) · alert (awaiting you)
  // · peek (unread) · sleepy (quiet for a week)
  property string mood: "calm"
  property bool animate: true

  readonly property real u: Math.min(width, height)   // unit size

  // Idle blinking, and a wake-up bounce when a bot starts waiting on you.
  property real blink: 1.0        // 1 = open, 0 = shut
  property real bounce: 0.0       // vertical offset in px
  property real gaze: 0.0         // -1 left … 1 right
  property real gazeY: 0.0        // -1 up … 1 down
  property real squash: 0.0       // >0 wider and shorter, <0 taller and thinner
  property real tilt: 0.0         // degrees
  property real spin: 0.0         // degrees, for the finishing flourish
  property real pop: 1.0          // uniform scale

  Timer {
    interval: 2600 + Math.random() * 4200
    running: root.animate && root.mood !== "sleepy"
    repeat: true
    onTriggered: { blinkAnim.restart(); interval = 2600 + Math.random() * 4200 }
  }

  SequentialAnimation {
    id: blinkAnim
    NumberAnimation { target: root; property: "blink"; to: 0.05; duration: 70; easing.type: Easing.InQuad }
    NumberAnimation { target: root; property: "blink"; to: 1.0; duration: 110; easing.type: Easing.OutQuad }
  }

  // Waiting on you: a slow, patient bob. Unread: one glance sideways.
  SequentialAnimation {
    running: root.animate && root.mood === "alert"
    loops: Animation.Infinite
    NumberAnimation { target: root; property: "bounce"; to: -root.u * 0.07; duration: 520; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "bounce"; to: 0; duration: 620; easing.type: Easing.OutBounce }
    PauseAnimation { duration: 900 }
    onStopped: root.bounce = 0
  }

  // Working: it breathes, rocks gently, and its eyes hunt around - the same
  // read as a person thinking with a pen in hand. Three loops of different
  // periods so it never looks like a metronome.
  SequentialAnimation {
    running: root.animate && root.mood === "working"
    loops: Animation.Infinite
    NumberAnimation { target: root; property: "squash"; to: 0.16; duration: 620; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "squash"; to: -0.10; duration: 760; easing.type: Easing.InOutSine }
    onStopped: root.squash = 0
  }

  SequentialAnimation {
    running: root.animate && root.mood === "working"
    loops: Animation.Infinite
    NumberAnimation { target: root; property: "tilt"; to: 7; duration: 900; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "tilt"; to: -7; duration: 900; easing.type: Easing.InOutQuad }
    onStopped: root.tilt = 0
  }

  SequentialAnimation {
    running: root.animate && root.mood === "working"
    loops: Animation.Infinite
    ParallelAnimation {
      NumberAnimation { target: root; property: "gaze"; to: 0.75; duration: 380; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "gazeY"; to: -0.55; duration: 380; easing.type: Easing.OutQuad }
    }
    PauseAnimation { duration: 520 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gaze"; to: -0.7; duration: 420; easing.type: Easing.InOutQuad }
      NumberAnimation { target: root; property: "gazeY"; to: -0.2; duration: 420; easing.type: Easing.InOutQuad }
    }
    PauseAnimation { duration: 460 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "gaze"; to: 0.1; duration: 340; easing.type: Easing.InOutQuad }
      NumberAnimation { target: root; property: "gazeY"; to: 0.35; duration: 340; easing.type: Easing.InOutQuad }
    }
    PauseAnimation { duration: 420 }
    onStopped: { root.gaze = 0; root.gazeY = 0 }
  }

  // Sleepy: a slow, shallow breath.
  SequentialAnimation {
    running: root.animate && root.mood === "sleepy"
    loops: Animation.Infinite
    NumberAnimation { target: root; property: "squash"; to: 0.07; duration: 2100; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "squash"; to: -0.03; duration: 2400; easing.type: Easing.InOutSine }
    onStopped: root.squash = 0
  }

  // Finished: one hop with a half spin, played when work ends. The app calls
  // its equivalent "celebrate"; this is the moment worth looking up for.
  SequentialAnimation {
    id: celebrateAnim
    ParallelAnimation {
      SequentialAnimation {
        NumberAnimation { target: root; property: "bounce"; to: -root.u * 0.34; duration: 240; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounce"; to: 0; duration: 380; easing.type: Easing.OutBounce }
      }
      NumberAnimation { target: root; property: "spin"; from: 0; to: 360; duration: 620; easing.type: Easing.InOutBack }
      SequentialAnimation {
        NumberAnimation { target: root; property: "pop"; to: 1.18; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "pop"; to: 1.0; duration: 420; easing.type: Easing.OutBack }
      }
    }
    onStopped: { root.spin = 0; root.pop = 1.0; root.bounce = 0 }
  }
  function celebrate() { if (root.animate) celebrateAnim.restart() }

  SequentialAnimation {
    running: root.animate && root.mood === "peek"
    loops: Animation.Infinite
    PauseAnimation { duration: 1800 }
    NumberAnimation { target: root; property: "gaze"; to: 0.6; duration: 300; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 700 }
    NumberAnimation { target: root; property: "gaze"; to: 0; duration: 300; easing.type: Easing.InOutQuad }
    onStopped: root.gaze = 0
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    y: root.bounce
    antialiasing: true
    transform: [
      Scale {
        origin.x: canvas.width / 2; origin.y: canvas.height
        xScale: root.pop * (1 + root.squash); yScale: root.pop * (1 - root.squash * 0.85)
      },
      Rotation {
        origin.x: canvas.width / 2; origin.y: canvas.height * 0.62
        angle: root.tilt + root.spin
      }
    ]
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var s = root.u, x0 = (width - s) / 2, y0 = (height - s) / 2
      ctx.save()
      ctx.translate(x0, y0)
      ctx.fillStyle = root.fill
      root.path(ctx, s)
      ctx.fill()
      root.face(ctx, s)
      ctx.restore()
    }
  }

  onShapeChanged: canvas.requestPaint()
  onFillChanged: canvas.requestPaint()
  onMoodChanged: canvas.requestPaint()
  onBlinkChanged: canvas.requestPaint()
  onGazeChanged: canvas.requestPaint()
  onGazeYChanged: canvas.requestPaint()
  onBounceChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  // ---------------------------------------------------------------- shapes
  // Each path is drawn in a unit box scaled to `s`. Approximations of the
  // app's silhouettes: close enough that a bot is recognisable at 12px.
  function path(ctx, s) {
    var f = function(v) { return v * s }
    ctx.beginPath()
    switch (shape) {
    case "circle":
      ctx.ellipse(0, 0, s, s); break
    case "egg":
      ctx.moveTo(f(0.5), f(0.01))
      ctx.bezierCurveTo(f(0.80), f(0.04), f(1.0), f(0.50), f(0.5), f(0.99))
      ctx.bezierCurveTo(f(0.0), f(0.50), f(0.20), f(0.04), f(0.5), f(0.01))
      break
    case "capsule":
      ctx.roundedRect(f(0.20), 0, f(0.60), s, f(0.30), f(0.30)); break
    case "cylinder":
      ctx.roundedRect(f(0.16), f(0.04), f(0.68), f(0.92), f(0.34), f(0.10)); break
    case "tablet":
      ctx.roundedRect(f(0.06), f(0.10), f(0.88), f(0.80), f(0.16), f(0.16)); break
    case "squircle":
      ctx.roundedRect(f(0.03), f(0.03), f(0.94), f(0.94), f(0.30), f(0.30)); break
    case "hex":
      ctx.moveTo(f(0.5), 0); ctx.lineTo(f(0.95), f(0.26)); ctx.lineTo(f(0.95), f(0.74))
      ctx.lineTo(f(0.5), f(1.0)); ctx.lineTo(f(0.05), f(0.74)); ctx.lineTo(f(0.05), f(0.26))
      ctx.closePath(); break
    case "gem":
      ctx.moveTo(f(0.5), 0); ctx.lineTo(f(1.0), f(0.38)); ctx.lineTo(f(0.78), f(1.0))
      ctx.lineTo(f(0.22), f(1.0)); ctx.lineTo(0, f(0.38)); ctx.closePath(); break
    case "crystal":
      ctx.moveTo(f(0.5), 0); ctx.lineTo(f(0.88), f(0.30)); ctx.lineTo(f(0.72), f(1.0))
      ctx.lineTo(f(0.28), f(1.0)); ctx.lineTo(f(0.12), f(0.30)); ctx.closePath(); break
    case "wedge":
      ctx.moveTo(f(0.5), f(0.02)); ctx.lineTo(f(0.98), f(0.94))
      ctx.quadraticCurveTo(f(0.5), f(1.06), f(0.02), f(0.94)); ctx.closePath(); break
    case "shield":
      ctx.moveTo(f(0.5), 0); ctx.lineTo(f(0.94), f(0.18))
      ctx.bezierCurveTo(f(0.94), f(0.70), f(0.76), f(0.92), f(0.5), f(1.0))
      ctx.bezierCurveTo(f(0.24), f(0.92), f(0.06), f(0.70), f(0.06), f(0.18))
      ctx.closePath(); break
    case "dome":
      ctx.moveTo(f(0.04), f(0.94))
      ctx.bezierCurveTo(f(0.04), f(0.16), f(0.96), f(0.16), f(0.96), f(0.94))
      ctx.quadraticCurveTo(f(0.5), f(1.04), f(0.04), f(0.94)); ctx.closePath(); break
    case "arch":
      ctx.moveTo(f(0.08), f(0.98)); ctx.lineTo(f(0.08), f(0.46))
      ctx.bezierCurveTo(f(0.08), f(0.0), f(0.92), f(0.0), f(0.92), f(0.46))
      ctx.lineTo(f(0.92), f(0.98)); ctx.closePath(); break
    case "bean":
      ctx.moveTo(f(0.42), f(0.03))
      ctx.bezierCurveTo(f(0.92), f(0.02), f(1.02), f(0.46), f(0.86), f(0.78))
      ctx.bezierCurveTo(f(0.68), f(1.04), f(0.24), f(1.02), f(0.12), f(0.72))
      ctx.bezierCurveTo(f(0.04), f(0.52), f(0.34), f(0.52), f(0.30), f(0.34))
      ctx.bezierCurveTo(f(0.27), f(0.20), f(0.30), f(0.06), f(0.42), f(0.03))
      break
    case "pebble":
      ctx.moveTo(f(0.38), f(0.04))
      ctx.bezierCurveTo(f(0.86), f(-0.04), f(1.06), f(0.44), f(0.90), f(0.72))
      ctx.bezierCurveTo(f(0.80), f(0.92), f(0.30), f(0.98), f(0.14), f(0.86))
      ctx.bezierCurveTo(f(-0.04), f(0.70), f(0.04), f(0.20), f(0.38), f(0.04))
      break
    case "cloud":
      ctx.moveTo(f(0.22), f(0.86))
      ctx.bezierCurveTo(f(-0.04), f(0.86), f(0.0), f(0.48), f(0.22), f(0.48))
      ctx.bezierCurveTo(f(0.20), f(0.10), f(0.72), f(0.06), f(0.76), f(0.42))
      ctx.bezierCurveTo(f(1.04), f(0.40), f(1.04), f(0.86), f(0.78), f(0.86))
      ctx.closePath(); break
    case "teardrop":
      ctx.moveTo(f(0.5), f(0.0))
      ctx.bezierCurveTo(f(0.92), f(0.42), f(1.0), f(0.66), f(0.84), f(0.86))
      ctx.bezierCurveTo(f(0.64), f(1.08), f(0.36), f(1.08), f(0.16), f(0.86))
      ctx.bezierCurveTo(f(0.0), f(0.66), f(0.08), f(0.42), f(0.5), f(0.0))
      break
    case "leaf":
      ctx.moveTo(f(0.08), f(0.92))
      ctx.bezierCurveTo(f(0.0), f(0.40), f(0.40), f(0.0), f(0.94), f(0.06))
      ctx.bezierCurveTo(f(1.0), f(0.60), f(0.60), f(1.0), f(0.08), f(0.92))
      ctx.closePath(); break
    case "group":
      // Two overlapping pebbles: a group chat rather than a single bot.
      ctx.ellipse(0, f(0.16), f(0.66), f(0.66))
      ctx.ellipse(f(0.34), f(0.16), f(0.66), f(0.66))
      break
    case "blob":
    default:
      ctx.moveTo(f(0.5), f(0.02))
      ctx.bezierCurveTo(f(0.86), f(0.0), f(1.02), f(0.30), f(0.94), f(0.58))
      ctx.bezierCurveTo(f(0.88), f(0.90), f(0.52), f(1.06), f(0.28), f(0.92))
      ctx.bezierCurveTo(f(0.02), f(0.76), f(-0.04), f(0.32), f(0.20), f(0.14))
      ctx.bezierCurveTo(f(0.30), f(0.06), f(0.40), f(0.02), f(0.5), f(0.02))
      break
    }
  }

  // ---------------------------------------------------------------- face
  function face(ctx, s) {
    if (s < 9) return                       // too small for eyes to read
    var eyeY = s * (shape === "arch" || shape === "dome" ? 0.56 : 0.50)
    var spread = s * 0.19
    var r = Math.max(1.0, s * (mood === "alert" ? 0.105 : 0.092))
    var cx = s * 0.5 + gaze * s * 0.05
    eyeY += gazeY * s * 0.035
    ctx.fillStyle = root.eyeColor

    if (mood === "working" && blink > 0.35) {
      // Narrowed, concentrating eyes rather than round ones.
      var ww = r * 1.9, wh = Math.max(1.0, r * 1.15 * blink)
      ctx.beginPath()
      ctx.roundedRect(cx - spread - ww / 2, eyeY - wh / 2, ww, wh, wh / 2, wh / 2)
      ctx.roundedRect(cx + spread - ww / 2, eyeY - wh / 2, ww, wh, wh / 2, wh / 2)
      ctx.fill()
      return
    }

    if (mood === "sleepy" || blink < 0.35) {
      // Closed eyes: two short lids.
      var w = r * 1.6, h = Math.max(0.8, r * 0.42)
      ctx.beginPath()
      ctx.roundedRect(cx - spread - w / 2, eyeY - h / 2, w, h, h / 2, h / 2)
      ctx.roundedRect(cx + spread - w / 2, eyeY - h / 2, w, h, h / 2, h / 2)
      ctx.fill()
      return
    }

    var squash = Math.max(0.12, blink)
    ctx.beginPath()
    ctx.ellipse(cx - spread - r, eyeY - r * squash, r * 2, r * 2 * squash)
    ctx.ellipse(cx + spread - r, eyeY - r * squash, r * 2, r * 2 * squash)
    ctx.fill()

    // Alert bots get a small raised brow over each eye.
    if (mood === "alert" && s >= 16) {
      var bw = r * 2.1, bh = Math.max(0.8, r * 0.34)
      ctx.beginPath()
      ctx.roundedRect(cx - spread - bw / 2, eyeY - r * 2.5, bw, bh, bh / 2, bh / 2)
      ctx.roundedRect(cx + spread - bw / 2, eyeY - r * 2.5, bw, bh, bh / 2, bh / 2)
      ctx.fill()
    }
  }
}
