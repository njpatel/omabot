import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omabot: your Grok Bot roster in the Omarchy bar. bin/omabot-watch follows the
// app's local state and streams it; this renders each bot as its own avatar -
// the shape and colour it has in the app - with an expression for its state:
// alert when it is waiting on you, glancing when it has unread messages,
// asleep when muted. Keys: j/k move · Enter focus the app · h redact ·
// r cycle the bar text · g group by channel · Esc close.

Panel {
  id: root
  moduleName: "njpatel.omabot"
  ipcTarget: "njpatel.omabot"
  manageIpc: false

  // ---------------------------------------------------------------- settings
  property string barMetric: String(setting("barMetric", "attention"))
  readonly property var barMetrics: ["attention", "all", "count", "none"]
  function cycleBarMetric() {
    barMetric = barMetrics[(barMetrics.indexOf(barMetric) + 1) % barMetrics.length]
    Quickshell.execDetached(["omarchy", "bar", "set", "njpatel.omabot", "barMetric", barMetric])
  }

  // attention: whoever wants you first (oldest wait first, so nobody is
  // buried), a rule, then everyone else by recency. channels: the sidebar
  // sections you set up in Grok Bot. flat: purely by recency.
  property string ordering: String(setting("ordering", "attention"))
  readonly property var orderings: ["attention", "channels", "flat"]
  function cycleOrdering() {
    ordering = orderings[(orderings.indexOf(ordering) + 1) % orderings.length]
    Quickshell.execDetached(["omarchy", "bar", "set", "njpatel.omabot", "ordering", ordering])
    cursor = 0
  }
  property bool groupBySection: String(setting("groupBySection", "true")) !== "false"
  function toggleGrouping() {
    groupBySection = !groupBySection
    Quickshell.execDetached(["omarchy", "bar", "set", "njpatel.omabot", "groupBySection", groupBySection ? "true" : "false"])
  }

  readonly property int maxBarAvatars: Math.max(1, Math.min(6, Number(setting("maxBarAvatars", 3))))
  readonly property string watcher: Qt.resolvedUrl("bin/omabot-watch").toString().replace(/^file:\/\//, "")

  function setting(name, fallback) {
    var s = root.settings || ({})
    return s[name] !== undefined && s[name] !== null ? s[name] : fallback
  }

  // ---------------------------------------------------------------- theme
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
  readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.20)
  readonly property color hilite: Qt.rgba(fg.r, fg.g, fg.b, 0.09)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color eyeInk: Color.background

  // ---------------------------------------------------------------- state
  property var snap: null
  property bool scrub: false
  property int cursor: 0
  property double nowMs: Date.now()

  readonly property var counts: snap && snap.counts ? snap.counts : ({})
  readonly property var bots: snap && snap.bots ? snap.bots : []
  readonly property var sections: snap && snap.sections ? snap.sections : []
  readonly property var app: snap && snap.app ? snap.app : ({})
  readonly property bool alarming: (counts.awaiting || 0) > 0
  readonly property bool attention: alarming || (counts.unread || 0) > 0

  // Bots that want you, most recently active first: the bar shows these.
  readonly property var wanting: {
    var out = []
    for (var i = 0; i < bots.length; i++) {
      var b = bots[i]
      if (b.awaiting || b.working || b.unread > 0) out.push(b)
    }
    var rank = function(x) { return x.awaiting ? 0 : (x.working ? 1 : 2) }
    out.sort(function(a, b) {
      if (rank(a) !== rank(b)) return rank(a) - rank(b)
      return (b.last_activity_ts || 0) - (a.last_activity_ts || 0)
    })
    return out
  }

  // Expression carries state. Muted is not it: most bots ship with
  // notifications off, and a roster of sleeping avatars says nothing. Gone
  // quiet for a week does say something, so that is what dozes.
  readonly property double staleAfterS: 7 * 24 * 3600
  function faceFor(b) {
    if (b.awaiting) return "attentive"
    if (b.unread > 1) return "excited"
    if (b.unread > 0) return "curious"
    if (b.last_activity_ts && (nowMs / 1000 - b.last_activity_ts) > staleAfterS) return "drowsy"
    return "neutral"
  }
  function colorFor(b) { return b.hex ? b.hex : (b.color === "black" ? fg : dim) }

  // Rows the cursor can land on, rebuilt whenever the view changes.
  readonly property var rows: {
    var out = []
    if (!snap) return out
    if (ordering === "attention") {
      var wants = [], rest = []
      for (var b = 0; b < bots.length; b++) {
        var bot = bots[b]
        ;(bot.awaiting || bot.unread > 0 ? wants : rest).push(bot)
      }
      // Waiting longest first: the one that has been ignored most deserves the top.
      wants.sort(function(x, y) { return (x.last_activity_ts || 0) - (y.last_activity_ts || 0) })
      rest.sort(function(x, y) { return (y.last_activity_ts || 0) - (x.last_activity_ts || 0) })
      for (var w = 0; w < wants.length; w++) out.push({ kind: "bot", bot: wants[w] })
      if (wants.length > 0 && rest.length > 0) out.push({ kind: "rule" })
      for (var r2 = 0; r2 < rest.length; r2++) out.push({ kind: "bot", bot: rest[r2] })
      return out
    }
    if (ordering === "channels" && sections.length > 0) {
      var byId = ({})
      for (var i = 0; i < bots.length; i++) byId[bots[i].id] = bots[i]
      for (var s = 0; s < sections.length; s++) {
        var ids = sections[s].bot_ids || []
        if (ids.length === 0) continue
        out.push({ kind: "section", name: sections[s].name, count: ids.length })
        for (var k = 0; k < ids.length; k++) if (byId[ids[k]]) out.push({ kind: "bot", bot: byId[ids[k]] })
      }
    } else {
      var sorted = bots.slice().sort(function(a, b) {
        return (b.last_activity_ts || 0) - (a.last_activity_ts || 0)
      })
      for (var j = 0; j < sorted.length; j++) out.push({ kind: "bot", bot: sorted[j] })
    }
    return out
  }
  readonly property var botRows: {
    var out = []
    for (var i = 0; i < rows.length; i++) if (rows[i].kind === "bot") out.push(i)
    return out
  }

  // ---------------------------------------------------------------- watcher
  Process {
    id: watcherProc
    command: [root.watcher, "--interval", "2"]
    running: true
    stdout: SplitParser { onRead: function(data) { root.parseState(data) } }
    stderr: SplitParser {
      onRead: function(data) { if (String(data).trim() !== "") console.warn("omabot", String(data).trim()) }
    }
    onExited: function(code) { console.warn("omabot", "watcher exited", code); restartTimer.start() }
  }
  Timer { id: restartTimer; interval: 5000; onTriggered: watcherProc.running = true }

  function parseState(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object") { root.snap = parsed; root.nowMs = Date.now() }
    } catch (e) {
      console.warn("omabot", "bad state line", e)
    }
  }

  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: root.nowMs = Date.now() }

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    cursor = 0
    panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    requestGreeting(false)
  }


  // Rows greet themselves when this fires: each avatar owns its own timing,
  // so there is no central loop to fall out of step with the list.
  signal greetRequested(bool everyone)

  Timer {
    id: greetOnOpen
    interval: 260
    onTriggered: root.greetRequested(greetEveryone)
    property bool greetEveryone: false
  }
  function requestGreeting(everyone) {
    greetOnOpen.greetEveryone = !!everyone
    greetOnOpen.restart()
  }

  // Focus the Grok Bot window. The app exposes no deep link to a single bot,
  // so this raises the app and leaves the choosing to you.
  function focusApp() {
    Quickshell.execDetached(["bash", "-c",
      "addr=$(hyprctl clients -j | python3 -c \"import sys,json;w=[c['address'] for c in json.load(sys.stdin) if c['class']=='grok-bot'];print(w[0] if w else '')\"); " +
      "if [ -n \"$addr\" ]; then hyprctl dispatch \"hl.dsp.focus({ window = \\\"address:$addr\\\" })\" || hyprctl dispatch focuswindow \"address:$addr\"; " +
      "else uwsm-app -- gtk-launch grok-bot; fi"])
    root.close()
  }

  IpcHandler {
    // Omarchy instantiates a bar widget more than once (a hidden copy is used
    // for measurement), and both copies would register for the same target -
    // the loser silently drops every call. Only the copy actually mounted in a
    // bar takes the name, so `omarchy-shell njpatel.omabot …` reaches the one
    // on screen.
    enabled: root.bar !== null
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function scrub(): string { root.scrub = !root.scrub; return root.scrub ? "scrubbed" : "clear" }
    function group(): string { root.cycleOrdering(); return root.ordering }
    function order(mode: string): string { root.ordering = mode; return root.ordering }
    // Play the greeting on demand: every bot, whether or not it has news.
    // Opens the panel first, because a panel loses focus - and closes - the
    // moment you type the command in a terminal.
    function greet(): string {
      if (!root.opened) root.open()
      root.requestGreeting(true)
      return "greeting"
    }
    function geometry(): string {
      return JSON.stringify({ x: panel.cardOrigin.x, y: panel.cardOrigin.y, w: panel.contentWidth, h: panel.contentHeight })
    }
    function state(): string {
      return JSON.stringify({ counts: root.counts, app: root.app, bots: root.bots.length })
    }
  }

  // ---------------------------------------------------------------- helpers
  function fmtAgo(ts) {
    if (!ts) return ""
    var s = Math.max(0, nowMs / 1000 - ts)
    if (s < 90) return "now"
    var m = Math.floor(s / 60)
    if (m < 60) return m + "m"
    var h = Math.floor(m / 60)
    if (h < 24) return h + "h"
    var d = Math.floor(h / 24)
    return d < 7 ? d + "d" : Math.floor(d / 7) + "w"
  }
  function noise(text) {
    var glyphs = "░▒▓█▓▒", h = 2166136261, out = ""
    for (var i = 0; i < text.length; i++) { h ^= text.charCodeAt(i); h = (h * 16777619) >>> 0 }
    for (var j = 0; j < text.length; j++) {
      h ^= h << 13; h >>>= 0; h ^= h >>> 17; h ^= h << 5; h >>>= 0
      out += glyphs.charAt(h % glyphs.length)
    }
    return out
  }
  function label(text) { text = String(text || ""); return scrub ? noise(text) : text }

  function moveCursor(delta) {
    if (botRows.length === 0) return
    var at = botRows.indexOf(cursor)
    if (at < 0) { cursor = botRows[0]; return }
    cursor = botRows[Math.max(0, Math.min(botRows.length - 1, at + delta))]
    ensureVisible()
  }
  function ensureVisible() {
    var item = repeater.itemAt(cursor)
    if (!item) return
    if (item.y < panelFlick.contentY) panelFlick.contentY = Math.max(0, item.y - Style.space(8))
    else if (item.y + item.height > panelFlick.contentY + panelFlick.height)
      panelFlick.contentY = Math.min(panelFlick.contentHeight - panelFlick.height,
                                     item.y + item.height - panelFlick.height + Style.space(8))
  }

  // ---------------------------------------------------------------- bar
  readonly property string barText: {
    if (!snap || barMetric === "none") return ""
    var c = counts
    if (barMetric === "count") return String(c.bots || 0)
    var parts = []
    if ((c.awaiting || 0) > 0) parts.push("!" + c.awaiting)
    if ((c.unread_messages || 0) > 0) parts.push(String(c.unread_messages))
    if (parts.length === 0 && (c.working || 0) > 0) parts.push("…")
    if (barMetric === "all" && parts.length === 0 && (c.bots || 0) > 0) parts.push(String(c.bots))
    return parts.join(" ")
  }
  readonly property string barTooltip: {
    if (!snap) return "Omabot"
    if (!app.running) return "Grok Bot is not running"
    var c = counts
    return (c.bots || 0) + " bots · " + (c.awaiting || 0) + " waiting on you · "
      + (c.working || 0) + " working · " + (c.unread_messages || 0) + " unread · Grok Bot "
      + (app.version || "?")
  }

  implicitWidth: row.implicitWidth
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property real openPanelIndicatorWidth: row.width

  // What the bar actually draws. "none" means the icon alone, like the other
  // widgets - never an empty slot, which would leave nothing to click and no
  // way back to the panel.
  readonly property bool vertical: !!(bar && bar.vertical)
  readonly property var barAvatars: (!snap || !app.running || vertical || barMetric === "none")
    ? [] : wanting.slice(0, maxBarAvatars)
  readonly property bool showIdleAvatar: !!snap && !!app.running && !vertical
    && barMetric !== "none" && wanting.length === 0 && bots.length > 0
  readonly property bool showIcon: barAvatars.length === 0 && !showIdleAvatar
  readonly property real barAvatarSize: Math.round(Style.font.caption * 1.15)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(4)

    // The bots that want you, as their own avatars. Nothing to say: one calm
    // avatar of the most recent bot, or the fallback glyph when idle.
    Row {
      id: avatars
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)
      visible: root.barAvatars.length > 0 || root.showIdleAvatar

      Repeater {
        model: root.barAvatars
        Avatar {
          width: root.barAvatarSize
          height: root.barAvatarSize
          shape: modelData.shape
          fill: root.colorFor(modelData)
          eyeColor: root.eyeInk
          face: root.faceFor(modelData)
        }
      }

      // Idle: a single calm bot so the widget still shows what it is.
      Avatar {
        visible: root.showIdleAvatar
        width: root.barAvatarSize
        height: root.barAvatarSize
        shape: root.bots.length > 0 ? root.bots[0].shape : "blob"
        fill: root.bots.length > 0 ? Qt.rgba(root.colorFor(root.bots[0]).r, root.colorFor(root.bots[0]).g,
                                             root.colorFor(root.bots[0]).b, 0.55) : root.dim
        eyeColor: root.eyeInk
        face: "neutral"
      }
    }

    // Fallback glyph while the watcher starts or the app is closed.
    BarIconButton {
      id: button
      visible: root.showIcon
      bar: root.bar
      text: "\u{f06a9}"
      onPressed: function(buttonCode) { root.barPressed(buttonCode) }
    }

    Text {
      id: metric
      anchors.verticalCenter: parent.verticalCenter
      visible: !(root.bar && root.bar.vertical) && root.barText !== ""
      text: root.barText
      color: root.alarming ? root.urgent : (root.bar ? root.bar.barForeground : root.fg)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: row
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: function(mouse) { root.barPressed(mouse.button) }
    onEntered: if (root.bar) root.bar.showTooltip(row, root.barTooltip)
    onExited: if (root.bar) root.bar.hideTooltip(row)
  }

  function barPressed(buttonCode) {
    if (buttonCode === Qt.RightButton) root.focusApp()
    else if (buttonCode === Qt.MiddleButton) root.cycleBarMetric()
    else root.toggle()
  }

  // ---------------------------------------------------------------- panel
  KeyboardPanel {
    id: panel
    anchorItem: row
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + Style.space(16), Style.space(900))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx < 0) root.scrub = !root.scrub
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.focusApp()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r") root.cycleBarMetric()
        else if (t === "g" || t === "G") root.cycleOrdering()
      }

      // Where the pointer is, in panel coordinates. Avatars map it into their
      // own space and lean toward it; -1 means "not over the panel".
      property real pointerX: -1
      property real pointerY: -1

      MouseArea {
        id: pointerTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onPositionChanged: function(mouse) { keyCatcher.pointerX = mouse.x; keyCatcher.pointerY = mouse.y }
        onExited: { keyCatcher.pointerX = -1; keyCatcher.pointerY = -1 }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Style.space(8)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          x: Style.space(4)
          width: parent.width - Style.space(8)
          spacing: 0

          // ---- header
          Item {
            width: parent.width
            height: header.implicitHeight + Style.space(10)
            Column {
              id: header
              width: parent.width
              spacing: Style.space(2)
              Text {
                text: {
                  if (!root.snap) return "starting…"
                  if (!root.app.running) return "GROK BOT · not running"
                  return "GROK BOT " + (root.app.version || "")
                }
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                visible: root.snap && root.app.running
                text: {
                  var c = root.counts
                  var bits = [(c.bots || 0) + " bots"]
                  if ((c.awaiting || 0) > 0) bits.push(c.awaiting + " waiting on you")
                  if ((c.working || 0) > 0) bits.push(c.working + " working")
                  if ((c.unread_messages || 0) > 0) bits.push(c.unread_messages + " unread")
                  if ((c.groups || 0) > 0) bits.push(c.groups + " group")
                  return bits.join(" · ")
                }
                color: root.alarming ? root.urgent : root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: root.faint }

          // ---- rows
          Repeater {
            id: repeater
            model: root.rows

            Item {
              id: rowItem
              required property var modelData
              required property int index
              width: column.width
              height: modelData.kind === "section" ? Style.space(26)
                    : modelData.kind === "rule" ? Style.space(13) : Style.space(46)

              // The break between "wants you" and everyone else.
              Rectangle {
                visible: modelData.kind === "rule"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: root.faint
              }

              // Bots with news get greeted when the panel opens.
              readonly property bool wantsGreeting: modelData.kind === "bot"
                && (modelData.bot.unread > 0 || modelData.bot.awaiting)

              Connections {
                target: root
                function onGreetRequested(everyone) {
                  if (rowItem.modelData.kind !== "bot") return
                  if (everyone || rowItem.wantsGreeting) rowGreet.restart()
                }
              }
              // Staggered by position so the flourishes read as a wave.
              Timer {
                id: rowGreet
                interval: 60 + rowItem.index * 85
                onTriggered: if (rowAvatar) rowAvatar.playRandom()
              }

              // section header
              Text {
                visible: modelData.kind === "section"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(4)
                text: root.label(modelData.name).toUpperCase() + "  " + (modelData.count || "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // bot row
              Rectangle {
                visible: modelData.kind === "bot"
                anchors.fill: parent
                anchors.leftMargin: -Style.space(4)
                anchors.rightMargin: -Style.space(4)
                radius: Style.space(3)
                color: index === root.cursor ? root.hilite : "transparent"

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(9)

                  Avatar {
                    id: rowAvatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(28)
                    height: Style.space(28)
                    shape: modelData.kind === "bot" ? modelData.bot.shape : "blob"
                    fill: modelData.kind === "bot" ? root.colorFor(modelData.bot) : root.dim
                    eyeColor: root.eyeInk
                    face: modelData.kind === "bot" ? root.faceFor(modelData.bot) : "neutral"

                    // Watch the pointer while it is over the panel.
                    readonly property point look: keyCatcher.pointerX < 0
                      ? Qt.point(-1, -1)
                      : mapFromItem(keyCatcher, keyCatcher.pointerX, keyCatcher.pointerY)
                    followX: look.x
                    followY: look.y

                    // Just read, or just answered: take a bow.
                    property bool wasWanted: false
                    onFaceChanged: {
                      var wants = face === "attentive" || face === "excited" || face === "curious"
                      if (wants) wasWanted = true
                      else if (wasWanted) { wasWanted = false; celebrate() }
                    }
                  }

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(28) - Style.space(9) - badge.width - Style.space(9)
                    spacing: Style.space(1)

                    Row {
                      spacing: Style.space(5)
                      width: parent.width
                      Text {
                        text: modelData.kind === "bot" ? root.label(modelData.bot.name) : ""
                        color: modelData.kind === "bot" && modelData.bot.focused ? root.accent : root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: modelData.kind === "bot" && (modelData.bot.awaiting || modelData.bot.unread > 0)
                      }
                      Text {
                        text: modelData.kind === "bot"
                          ? (modelData.bot.is_group ? "group of " + modelData.bot.members
                                                    : root.label(modelData.bot.title))
                          : ""
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: Math.max(0, parent.width - Style.space(120))
                      }
                    }

                    Text {
                      width: parent.width
                      text: modelData.kind === "bot"
                        ? (modelData.bot.working ? "thinking…" : root.label(modelData.bot.last_text))
                        : ""
                      color: modelData.kind === "bot" && modelData.bot.awaiting ? root.urgent
                             : (modelData.kind === "bot" && modelData.bot.working ? root.accent : root.dim)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }

                  Column {
                    id: badge
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(38)
                    spacing: Style.space(2)

                    Text {
                      anchors.right: parent.right
                      text: modelData.kind === "bot" ? root.fmtAgo(modelData.bot.last_activity_ts) : ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Rectangle {
                      anchors.right: parent.right
                      visible: modelData.kind === "bot" && modelData.bot.unread > 0
                      width: Math.max(Style.space(14), unreadText.implicitWidth + Style.space(6))
                      height: Style.space(14)
                      radius: height / 2
                      color: root.accent
                      Text {
                        id: unreadText
                        anchors.centerIn: parent
                        text: modelData.kind === "bot" ? String(modelData.bot.unread) : ""
                        color: Color.background
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.cursor = index
                  onClicked: root.focusApp()
                }
              }
            }
          }

          // ---- empty states
          Text {
            visible: root.snap && root.bots.length === 0
            width: parent.width
            topPadding: Style.space(10)
            text: root.app.running ? "no bots in the roster yet" : "start Grok Bot to see your bots"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Rectangle { width: parent.width; height: 1; color: root.faint; visible: root.bots.length > 0 }

          // ---- footer
          Item {
            width: parent.width
            height: Style.space(30)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "j/k move · ⏎ open app · g " + root.ordering
                    + " · h hide · r bar " + root.barMetric
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
