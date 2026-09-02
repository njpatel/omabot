![Omabot](assets/title.png)

<!--
 ▄█████▄    ▄███████████▄    ▄███████    ▄███████▄    ▄█████▄   ███████████
███   ███  ███   ███   ███  ███   ███  ███   ███   ███   ███      ███
███   ███  ███   ███   ███  ███   ███  ███   ███   ███   ███      ███
███   ███  ███   ███   ███  ███▄▄▄███  ███▄▄▄██▀   ███   ███      ███
███   ███  ███   ███   ███  ███▀▀▀███  ███▀▀▀██▄   ███   ███      ███
███   ███  ███   ███   ███  ███   ███  ███   ███   ███   ███      ███
███   ███  ███   ███   ███  ███   ███  ███  ▄███   ███   ███      ███
 ▀█████▀    ▀█   ███   █▀   ███   █▀    ▀███████▀   ▀█████▀       ███
-->

Your [Grok Bot](https://x.ai/bot) roster in the [Omarchy](https://omarchy.org) bar. Every bot is drawn as itself - the shape and colour it has in the app - wearing the face of whatever it wants from you.

![The roster, whoever needs you first](assets/omabot.png)

## Install

```sh
omarchy plugin add https://github.com/njpatel/omabot.git --enable
omarchy restart shell
```

Nothing to configure. Omabot reads the state Grok Bot already keeps on disk, so it needs the desktop app and `python3` and nothing else. It never touches the network, and it only ever reads - Grok Bot is left alone.

Remove with `omarchy plugin remove njpatel.omabot`. It leaves nothing behind.

## In the bar

The Grok Bot mark is always there, dimmed when the app is not running. Beside it are the bots waiting on you, drawn as themselves. Nothing beside the mark means nothing needs you.

![What sits beside the mark](assets/bar.png)

Bring the pointer near and they look up at you, one after another.

| | |
|---|---|
| click | open the panel |
| right-click | jump to Grok Bot |
| middle-click | cycle what sits beside the mark |

## In the panel

Every bot, with its title, its last message, how long ago, and an unread badge. By default the ones waiting on you come first - longest wait at the top, so nobody is buried - then a rule, then everyone else by recency.

| key | |
|---|---|
| `j` `k` | move |
| `Enter` | open Grok Bot |
| `g` | cycle the order: waiting first, by channel, or purely by recency |
| `h` | redact names and messages, for sharing a screen |
| `r` | cycle what sits beside the mark |
| `Esc` | close |

The avatars greet you when the panel opens, and their eyes follow the pointer while it is over the list.

![The greeting, and the eyes](assets/faces.gif)

## Faces

There is no expression in Grok Bot's data - the app stores a shape, a colour and a pair of eyes. The face is Omabot's reading of what a bot is doing:

| | |
|---|---|
| **eyes up, leaning in** | waiting on your answer |
| **wide-eyed** | more than one unread message |
| **head tilted** | one unread message |
| **half-closed, breathing** | nothing for a week |
| **level** | up to date |

A bot that has been sent a message nobody has answered yet says `thinking…` in place of its last line.

## Settings

Set on the bar entry, or with the keys above:

```sh
omarchy bar set njpatel.omabot barMetric count      # avatars · count · none
omarchy bar set njpatel.omabot ordering channels    # attention · channels · flat
omarchy bar set njpatel.omabot maxBarAvatars 4      # 1-6
```

`omarchy-shell njpatel.omabot demo` swaps in a staged roster - fourteen invented bots across two channels - for screenshots and for showing the thing off. Call it again for the real one.

## How it works

Grok Bot keeps its client state in `~/.config/Grok Bot/sand-client-persistence`, as blobs whose filenames are base32 of the state key. `bin/omabot-watch` decodes those, follows the roster, the channels and the session marker, and streams a normalised snapshot as JSON lines; `Widget.qml` renders it, and `Avatar.qml` draws the eighteen shapes and the colour palette taken from the app bundle, so a bot looks the same here as it does there.

None of that is a documented contract - the roster is at `schemaVersion` 4 - so every field is read defensively, and an unfamiliar shape degrades to an empty roster rather than a broken bar. If a Grok Bot update moves things, `bin/omabot-watch` is the file to fix.

## License

Apache-2.0
