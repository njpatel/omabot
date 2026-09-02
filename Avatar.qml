import QtQuick

// A Grok Bot avatar: the bot's own shape and colour, with eyes that sit on a
// sphere and a face that carries its state.
//
// The eye geometry is ported from grokbots.ai's studio: two eyes placed on a
// sphere by a yaw/pitch/roll gaze, each with its own width, height, tilt and
// openness, projected to 2D with a depth term. That projection is what makes a
// flat blob read as a head that is looking somewhere - and it is why the eyes
// can follow your pointer rather than merely sliding about. The pose table and
// the spring constants come from the same source; the shape silhouettes and
// the colour palette come from the desktop app's own bundle.
Item {
  id: root

  property string shape: "squircle"
  property color fill: "#777777"
  property color eyeColor: "#111111"
  property bool animate: true

  // Which face to wear. The cheerful half of the studio's set: it also ships
  // angry, sad and frightened, which have no business describing an inbox.
  //   neutral · attentive · surprised · excited · happy · delighted
  //   curious · proud · shy · unimpressed · drowsy · doubtful · confused
  property string face: "neutral"

  // Where it is looking, in degrees. Animated by the flourishes, or aimed at
  // the pointer when followX/followY are set.
  property real yaw: 0
  property real pitch: 0
  property real roll: 0

  readonly property real u: Math.min(width, height)

  // ---------------------------------------------------------------- poses
  // [yaw, pitch, roll, split,
  //  leftW, leftH, leftTilt, leftOpen, rightW, rightH, rightTilt, rightOpen]
  readonly property var poses: ({
    "neutral":     [0,   0,   0, 15.46, 0.186, 0.412,   0, 1.0,  0.186, 0.412,   0, 1.0],
    "attentive":   [4,   5,  -4, 16.0,  0.21,  0.44,    0, 1.0,  0.21,  0.44,    0, 1.0],
    "surprised":   [3,  -3,   0, 19.0,  0.45,  0.47,    0, 1.0,  0.45,  0.47,    0, 1.0],
    "excited":     [6, -14,   0, 19.5,  0.40,  0.56,  -10, 1.0,  0.40,  0.56,   10, 1.0],
    "happy":       [5,   9,   0, 17.0,  0.27,  0.17,   14, 1.0,  0.27,  0.17,  -14, 1.0],
    "delighted":   [4,  14,   0, 18.0,  0.34,  0.13,   20, 1.0,  0.34,  0.13,  -20, 1.0],
    "curious":    [16,  -9, -15, 16.5,  0.24,  0.46,   -8, 1.0,  0.20,  0.38,   -8, 1.0],
    "proud":       [5,  17,   0, 17.0,  0.30,  0.15,   18, 1.0,  0.30,  0.15,  -18, 1.0],
    "shy":       [-19, -14,  -7, 14.0,  0.17,  0.30,    0, 1.0,  0.17,  0.30,    0, 1.0],
    "unimpressed":[-22,  2,   0, 16.0,  0.30,  0.12,    0, 1.0,  0.30,  0.12,    0, 1.0],
    "drowsy":      [6,  -9,  -3, 16.0,  0.20,  0.42,    0, 0.42, 0.20,  0.42,    0, 0.42],
    "doubtful":   [12,   6,  -6, 16.0,  0.21,  0.40,    0, 1.0,  0.22,  0.15,    0, 1.0],
    "confused":  [-14,   3,   8, 16.5,  0.20,  0.44,  -18, 1.0,  0.28,  0.17,   14, 1.0]
  })
  readonly property var pose: poses[face] !== undefined ? poses[face] : poses["neutral"]

  // Blink scales the pose's openness rather than replacing it, so a drowsy bot
  // blinks from half-shut and a surprised one from wide.
  property real blink: 1.0

  // ---------------------------------------------------------------- motion
  property real bounce: 0.0
  property real squash: 0.0
  property real tilt: 0.0
  property real spin: 0.0
  property real pop: 1.0

  // Aim at a point in this item's coordinates. The point is usually outside
  // the avatar - a bot at the top of a list looking down at a cursor near the
  // bottom - so the coordinates are free to be negative or far larger than the
  // item, and `looking` says whether to aim at all. Getting that wrong is why
  // half a list can appear frozen: only the rows whose mapped point happened
  // to be positive would turn.
  property bool looking: false
  property real followX: 0
  property real followY: 0
  readonly property bool following: looking

  // Direction to the point, saturating a couple of avatar-widths away, so a
  // distant cursor still turns every head fully toward it.
  readonly property real reachX: Math.max(1, width * 2.2)
  readonly property real reachY: Math.max(1, height * 2.2)
  readonly property real aimYaw: following
    ? Math.max(-1, Math.min(1, (followX - width / 2) / reachX)) * 26 : 0
  readonly property real aimPitch: following
    ? Math.max(-1, Math.min(1, (height / 2 - followY) / reachY)) * 20 : 0

  // The studio turns its heads with spring(stiffness 320, damping 26, mass .6);
  // these are the Qt equivalents, tuned to the same overshoot-and-settle feel.
  Behavior on yaw { enabled: root.following; SpringAnimation { spring: 3.4; damping: 0.28; mass: 0.6; epsilon: 0.05 } }
  Behavior on pitch { enabled: root.following; SpringAnimation { spring: 3.4; damping: 0.28; mass: 0.6; epsilon: 0.05 } }

  // Following bends the pose's own gaze toward the pointer rather than
  // replacing it, so each face keeps its character while it watches you.
  function restGaze() {
    if (following) {
      yaw = pose[0] * 0.35 + aimYaw
      pitch = pose[1] * 0.35 + aimPitch
    } else {
      yaw = pose[0]; pitch = pose[1]
    }
    roll = pose[2]
  }
  onFollowXChanged: if (following) restGaze()
  onFollowYChanged: if (following) restGaze()
  onLookingChanged: restGaze()
  onFollowingChanged: restGaze()
  onFaceChanged: restGaze()
  Component.onCompleted: restGaze()

  Timer {
    interval: 2800 + Math.random() * 4600
    running: root.animate
    repeat: true
    onTriggered: { blinkAnim.restart(); interval = 2800 + Math.random() * 4600 }
  }

  SequentialAnimation {
    id: blinkAnim
    NumberAnimation { target: root; property: "blink"; to: 0.06; duration: 90; easing.type: Easing.InQuad }
    NumberAnimation { target: root; property: "blink"; to: 1.0; duration: 150; easing.type: Easing.OutQuad }
  }

  // ---------------------------------------------------------------- flourishes
  // One-shot and unhurried: the studio's keyframe animations run 0.8-2.4s, so
  // these sit at the quick end of that range rather than the twitchy end.
  SequentialAnimation {
    id: hopAnim
    NumberAnimation { target: root; property: "bounce"; to: -root.u * 0.26; duration: 380; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "bounce"; to: 0; duration: 620; easing.type: Easing.OutBounce }
    onStopped: root.bounce = 0
  }

  SequentialAnimation {
    id: wiggleAnim
    NumberAnimation { target: root; property: "tilt"; to: 13; duration: 260; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tilt"; to: -11; duration: 320; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tilt"; to: 6; duration: 280; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tilt"; to: 0; duration: 320; easing.type: Easing.OutBack }
    onStopped: root.tilt = 0
  }

  SequentialAnimation {
    id: popAnim
    ParallelAnimation {
      NumberAnimation { target: root; property: "pop"; to: 1.16; duration: 260; easing.type: Easing.OutBack }
      NumberAnimation { target: root; property: "squash"; to: -0.11; duration: 260; easing.type: Easing.OutQuad }
    }
    ParallelAnimation {
      NumberAnimation { target: root; property: "pop"; to: 1.0; duration: 620; easing.type: Easing.OutBounce }
      NumberAnimation { target: root; property: "squash"; to: 0; duration: 620; easing.type: Easing.OutBounce }
    }
    onStopped: { root.pop = 1.0; root.squash = 0 }
  }

  SequentialAnimation {
    id: nodAnim
    NumberAnimation { target: root; property: "pitch"; to: root.pose[1] - 15; duration: 320; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "squash"; to: 0.10; duration: 200; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "squash"; to: 0; duration: 340; easing.type: Easing.OutBack }
    NumberAnimation { target: root; property: "pitch"; to: root.pose[1]; duration: 440; easing.type: Easing.InOutSine }
    onStopped: { root.squash = 0; root.restGaze() }
  }

  // A look around: the head turns, not merely the pupils.
  SequentialAnimation {
    id: lookAnim
    NumberAnimation { target: root; property: "yaw"; to: root.pose[0] - 22; duration: 440; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 280 }
    NumberAnimation { target: root; property: "yaw"; to: root.pose[0] + 22; duration: 580; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 240 }
    NumberAnimation { target: root; property: "yaw"; to: root.pose[0]; duration: 440; easing.type: Easing.InOutSine }
    onStopped: root.restGaze()
  }

  SequentialAnimation {
    id: celebrateAnim
    ParallelAnimation {
      SequentialAnimation {
        NumberAnimation { target: root; property: "bounce"; to: -root.u * 0.34; duration: 320; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounce"; to: 0; duration: 560; easing.type: Easing.OutBounce }
      }
      NumberAnimation { target: root; property: "spin"; from: 0; to: 360; duration: 880; easing.type: Easing.InOutBack }
      SequentialAnimation {
        NumberAnimation { target: root; property: "pop"; to: 1.18; duration: 300; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "pop"; to: 1.0; duration: 580; easing.type: Easing.OutBack }
      }
    }
    onStopped: { root.spin = 0; root.pop = 1.0; root.bounce = 0 }
  }
  function celebrate() { if (root.animate) celebrateAnim.restart() }

  readonly property var flourishes: [hopAnim, wiggleAnim, popAnim, nodAnim, lookAnim, celebrateAnim]
  readonly property int flourishCount: flourishes.length

  // Play a particular flourish, so a caller greeting several avatars at once
  // can hand each of them a different one.
  function play(index) {
    if (!root.animate) return
    var n = flourishes.length
    var pick = flourishes[((index % n) + n) % n]
    if (pick) pick.restart()
  }
  function playRandom() { play(Math.floor(Math.random() * flourishes.length)) }

  // ---------------------------------------------------------------- render
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
      root.drawFace(ctx, s)
      ctx.restore()
    }
  }

  onShapeChanged: canvas.requestPaint()
  onFillChanged: canvas.requestPaint()
  onBlinkChanged: canvas.requestPaint()
  onYawChanged: canvas.requestPaint()
  onPitchChanged: canvas.requestPaint()
  onRollChanged: canvas.requestPaint()
  onBounceChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  // ---------------------------------------------------------------- eyes in 3D
  // Rotate two orthogonal basis vectors about their shared normal.
  function spin2(a, b, angle) {
    var c = Math.cos(angle), s = Math.sin(angle)
    return [[a[0] * c + b[0] * s, a[1] * c + b[1] * s, a[2] * c + b[2] * s],
            [b[0] * c - a[0] * s, b[1] * c - a[1] * s, b[2] * c - a[2] * s]]
  }

  // Both eyes on a sphere of radius r for the current gaze: position, the
  // local right/up basis, and depth (z, positive toward the viewer).
  function eyePlacement(r, split) {
    var rad = function(d) { return d * Math.PI / 180 }
    var fwd = [0, 0, 1], right = [1, 0, 0], up = [0, 1, 0], pair
    pair = spin2(fwd, right, rad(yaw)); fwd = pair[0]; right = pair[1]
    pair = spin2(up, fwd, rad(pitch)); up = pair[0]; fwd = pair[1]
    pair = spin2(right, up, rad(roll)); right = pair[0]; up = pair[1]
    var at = function(side) {
      var p = spin2(fwd, right, rad(split * side))
      return { x: p[0][0] * r, y: p[0][1] * r, ax: p[1][0], ay: p[1][1], depth: p[0][2] }
    }
    return [at(-1), at(1)]
  }

  function drawFace(ctx, s) {
    if (s < 9) return
    var r = s * 0.5
    var eyes = eyePlacement(r * 0.92, pose[3])
    ctx.fillStyle = root.eyeColor
    for (var i = 0; i < 2; i++) {
      var e = eyes[i]
      if (e.depth < -0.1) continue                 // round the back of the head
      var base = 4 + i * 4
      var ew = pose[base] * r, eh = pose[base + 1] * r
      var etilt = pose[base + 2] * Math.PI / 180
      var open = pose[base + 3] * blink
      // Foreshorten with depth, so the far eye narrows as the head turns away.
      var fore = Math.max(0.22, 0.55 + 0.45 * e.depth)
      ctx.save()
      ctx.translate(r + e.x, r + e.y)
      ctx.rotate(Math.atan2(e.ay, e.ax) + etilt)
      ctx.beginPath()
      var hw = Math.max(0.6, ew * 0.5 * fore)
      var hh = Math.max(0.5, eh * 0.5 * Math.max(0.06, open))
      ctx.ellipse(-hw, -hh, hw * 2, hh * 2)
      ctx.fill()
      ctx.restore()
    }
  }

  // ---------------------------------------------------------------- shapes
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
}
