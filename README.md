# terminal-images

See an image in the terminal, with one command:

```sh
chafa picture.png
```

That is the whole tool. This repo installs it, and ships a probe that tells you whether
your terminal can draw pictures at all — which is the part that actually goes wrong.

```sh
git clone https://github.com/Gin111191/terminal-images ~/terminal-images
~/terminal-images/install.sh
```

---

## Whether it works is decided by the terminal, not by chafa

To draw a picture a terminal has to implement an escape-sequence protocol, and most do not:

| Protocol | Who speaks it |
|---|---|
| **Kitty graphics** | Kitty, Ghostty, WezTerm |
| **Sixel** | WezTerm, foot, xterm (`-ti vt340`), mlterm, Windows Terminal (recent) |
| **iTerm2 inline** | iTerm2, WezTerm |

`chafa` works out which one is available and uses it. Where there is none it falls back to
coloured Unicode blocks, so it always prints *something* — which makes "did it work?"
ambiguous. To settle it, force the fallback and compare:

```sh
chafa -f symbols picture.png
```

A real protocol looks like a photograph. The fallback looks like a mosaic.

## Where the pipe breaks

Measured on a Mac driving a WSL2 box:

| # | Path | Images? | Why |
|---|---|---|---|
| 1 | Windows → conhost → WSL | **No** | conhost implements no image protocol at all |
| 1b | Windows → WezTerm → WSL | Yes | WezTerm is the terminal; WSL is just a shell in it |
| 2 | Mac → WezTerm | Yes | the simple case |
| 3 | Mac → WezTerm → ssh Windows → `wsl` | Unreliable | Windows' **ConPTY** sits in the middle |
| 4 | Mac → WezTerm → **ssh straight into WSL** | Yes | Windows is out of the path entirely |

**Row 3 is the trap, row 4 is the answer.** Reaching WSL by SSHing to Windows and running
`wsl.exe` puts ConPTY — the Windows console layer — between WezTerm and chafa. Give the
distro its own sshd and connect to it directly instead;
[wsl-autostart](https://github.com/Gin111191/wsl-autostart) keeps it running so there is
something to reach.

Plain SSH is not a problem. It is a transparent byte pipe: the escape sequence arrives
intact and the terminal draws it. Only ConPTY is.

## tmux

tmux will not forward an escape sequence it does not recognise. One line:

```tmux
set -g allow-passthrough on
```

Already set in [tmux-config](https://github.com/Gin111191/tmux-config). A **running** tmux
server keeps the settings it started with, so reload (`prefix` + `r`) or `tmux kill-server`
after adding it.

Test outside tmux first, then inside — that way a failure names the layer that broke it.

## Verify

```sh
~/terminal-images/imgprobe.sh
```

It asks the terminal directly — `\033[c` for sixel, a Kitty query packet for Kitty
graphics — and prints what came back:

```
TERM=xterm-256color  TERM_PROGRAM=WezTerm  TMUX=no
DA1 reply: [?65;4;6;18;22c
  sixel:          YES
  kitty graphics: YES
  iterm2 inline:  YES (by terminal identity)
```

It needs a **real terminal**: it puts the tty in raw mode and reads the reply. Run it from
your own shell — not through a pipe, `ssh host cmd`, or an agent's tool call.

## When it does not work

| Symptom | Cause | Fix |
|---|---|---|
| `imgprobe.sh` prints `<silence>` | the terminal ignored the query | it has no image protocol — conhost, `screen`, most CI shells |
| Coloured blocks everywhere | no protocol, chafa fell back to symbols | change terminal; nothing else here helps |
| Works locally, blocks over SSH | chafa could not identify the terminal | `chafa -f kitty picture.png` |
| Works outside tmux, not inside | `allow-passthrough` missing, or a stale server | `tmux kill-server` and reconnect |
| Picture appears, then vanishes on scroll | normal — these protocols do not survive reflow | draw it again |

### The SSH environment gap

SSH forwards `TERM`. It does **not** forward `TERM_PROGRAM`, so on the far side nothing can
identify the terminal by that variable:

```sh
echo $TERM_PROGRAM     # "WezTerm" locally, empty over ssh
```

If chafa degrades to symbols over SSH, that is why. Force the format — one flag, no root:

```sh
chafa -f kitty picture.png
```

## What this deliberately does not do

**No Neovim plugin.** snacks.image and 3rd/image.nvim both work, and both cost more than
they return: a plugin, an ImageMagick dependency, and the same terminal-detection problem
again — which fails exactly where you need it, inside tmux over SSH. `chafa` at the prompt
is one command and no config.

**No images inside Claude Code.** Not a setting; the feature does not exist —
[anthropics/claude-code#54546](https://github.com/anthropics/claude-code/issues/54546) and
several duplicates. Claude Code paints the alternate screen buffer and repaints every
frame, so anything drawn into it is wiped on the next render. A `tmux popup` is the usual
suggested way around that; it did not draw here either. Leave Claude Code, run `chafa`,
come back.

## Related

- [wsl-autostart](https://github.com/Gin111191/wsl-autostart) — keeps the WSL distro up so row 4 has something to reach
- [tmux-config](https://github.com/Gin111191/tmux-config) — where `allow-passthrough` lives
