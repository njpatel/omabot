# Working on omabot

> Not called `AGENTS.md`, and not at the repository root, on purpose. Omarchy
> installs a plugin's whole tree into `~/.config/omarchy/plugins/`, so a root
> agent-instruction file would become ambient context for any coding agent the
> *installing user* happens to run — instructions they never chose to load.
> Marketplace review raised this on omapager; the same reasoning applies here.
> If you keep a `CLAUDE.md` symlink to this file locally, leave it untracked.

Your Grok Bot roster in the Omarchy bar. It reads state the Grok Bot desktop
app already keeps on disk and renders each bot as itself — the shape and colour
the app gives it, or the picture you set — wearing a face for what it wants
from you.

**It only ever reads.** Grok Bot is never written to, never signalled, never
asked over the network. If a change here would write to `~/.config/Grok Bot`,
it is the wrong change.

## Layout

| | |
| --- | --- |
| `bin/omabot-watch` | follows Grok Bot's local state, streams JSON lines on stdout |
| `Widget.qml` | the bar entry and the panel; **also where settings live** |
| `Avatar.qml` | one bot, drawn: shape, colour, eyes, expression, flourishes |

Settings only reach a bar widget, never a service, so everything configurable
is read in `Widget.qml` from the plugin's `shell.json` entry: `barMetric`,
`ordering`, `groupBySection`, `maxBarAvatars`.

## Running and testing

```bash
qmllint Widget.qml Avatar.qml     # CHECK THE EXIT CODE; its stderr is easy to lose
omarchy-restart-shell             # reload (never omarchy-refresh-shell)
bin/omabot-watch --interval 2     # the raw stream, one JSON line per change
omarchy-shell njpatel.omabot demo # staged roster, again to go back
```

`demo` is the way to see states you cannot summon: fourteen invented bots
across two channels, three of them waiting. It is held in memory, which is why
it is an IPC verb rather than a setting — writing the bar entry reloads the
widget and would throw the roster away. `scrub` redacts names and messages for
a screen share; `group` / `order` cycle the ordering.

**Hot reload does not recreate `Variants` windows.** Editing `Widget.qml` or
`Avatar.qml` means a full restart, or you are looking at the old surface and
chasing a bug that is not there.

## Things that cost a day to learn

**Grok Bot's state is not a contract**

- It lives in `~/.config/Grok Bot/sand-client-persistence`, as `.blob` files
  whose **filenames are base32 of the state key** — `decode_key()` is what
  turns them back into names like `roster.last-roster`. Keys are matched by
  *suffix*, because the prefix has changed before.
- The roster is at `schemaVersion` 4 and nobody promised it would stay. Every
  field is read defensively and an unfamiliar shape degrades to an empty roster
  rather than a broken bar. If an app update moves things, `bin/omabot-watch`
  is the one file to fix.
- **Liveness comes from `sand-session-marker.json`**, not from a process scan:
  `aliveAtMs` within 120s means running. That is why the bar mark dims without
  omabot ever looking for a PID.

**Reading it cheaply**

- Transcripts are large and change rarely, so `working_state()` caches by
  **mtime**. Avatars are cached the same way, and decoded per `version` so an
  unchanged picture costs nothing and a changed one writes a new file.
- A bot is *working* when its transcript ends on a user message with no
  `send-message` after it. The app streams replies over its gateway and only
  persists the finished message, so this is the honest local signal — but it is
  **capped at 900s**, because a reply that never came should not leave a bot
  working forever.
- Avatars arrive as base64 data URLs inside one blob. They are decoded to files
  under `~/.local/state/omarchy/omabot/avatars/`, because QML wants files and a
  200KB string per bot has no business crossing a JSON line every two seconds.
  Files nobody wears any more are swept, or changing an avatar twice leaves
  dead ones behind.

**Drawing a bot**

- The eye geometry is ported from grokbots.ai's studio: two eyes placed on a
  sphere by a yaw/pitch/roll gaze, each with its own width, height, tilt and
  openness. The `poses` table is that data, not something invented here — keep
  it in the studio's order so it can be diffed against them.
- **The eyes are holes, not paint.** The bar mark is a single flat colour, so
  eyes have to be punched through for whatever is behind the bar to show — in
  any theme. Painting them works in the panel and disappears in the bar.
- Expression carries state, and **muted is not a state worth drawing**: most
  bots ship with notifications off, and a roster of sleeping avatars says
  nothing. Gone quiet for a week does say something, so that is what dozes.
- The face set is the cheerful half of the studio's. It also ships angry, sad
  and frightened, which have no business describing an inbox.
- **At bar size most animation is invisible.** A nod or a look-around turns the
  head, which reads at panel size and moves an eye by a pixel at 13px — you see
  a blink that happens to land nearby and nothing else. Only flourishes that
  still read small belong in the bar.

## State

`~/.local/state/omarchy/omabot/avatars/` — decoded pictures, named by version,
swept when unworn. Nothing else is kept, and nothing is written to the journal.

## Conventions

Comments say **why**, and especially why not the obvious thing. Keep them when
you move code; delete them when they stop being true. No new runtime
dependencies: Quickshell, Python 3, and the Grok Bot app itself.

## Contributing

### How we review contributions

We review the idea first: does it fit the project, and does it solve a useful problem?

If it does, we prefer helping it land over sending you through repeated rounds of small adjustments. We’ll offer directly applicable suggestions where useful. For remaining maintainer preferences, we may prepare and verify a follow-up fix, merge your contribution, then land our adjustments immediately afterwards. Your contribution keeps its GitHub authorship and credit; our follow-up changes are ours.

Further review rounds are appropriate when the idea fits but the implementation still has substantial correctness, security or design problems. We may also offer to finish the agreed changes on your PR branch, with your consent and without rewriting your commits.

We won’t knowingly merge a broken or unsafe intermediate version. Required checks and release or verification gates still apply. If a contribution doesn’t fit the project, we’ll explain that and close it rather than leave it waiting indefinitely.
