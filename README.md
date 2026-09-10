# terminal-images

See real images in a terminal — in the **shell**, in **Neovim**, and in the **Claude Code**
transcript — on the machine you are sitting at *and* over SSH.

Two packages and one probe script. The hard part is not installing them; it is knowing
which terminal can draw at all, and that is what `imgprobe.sh` answers.

```sh
git clone https://github.com/Gin111191/terminal-images ~/terminal-images
~/terminal-images/install.sh
```

---

## The problem

A terminal draws text. To draw a *picture* it has to implement one of three escape-sequence
protocols, and most terminals implement none:

| Protocol | Who speaks it |
|---|---|
| **Kitty graphics** | Kitty, Ghostty, WezTerm |
| **Sixel** | WezTerm, foot, xterm (`-ti vt340`), mlterm, Windows Terminal (recent) |
| **iTerm2 inline** | iTerm2, WezTerm |

WezTerm speaks all three, which is why everything here is written around it.

The thing that draws — `chafa`, Neovim, Claude Code — only emits the sequence. Whether a
picture appears is decided entirely by the terminal at the other end of the pipe, which may
be several hops away.

## What works, and where

Measured on a Mac driving a WSL2 box:

| # | Path | Images? | Why |
|---|---|---|---|
| 1 | Windows → conhost → WSL | **No** | conhost implements no image protocol at all |
| 1b | Windows → WezTerm → WSL | Yes | WezTerm is the terminal; WSL is just a shell in it |
| 2 | Mac → WezTerm | Yes | the simple case |
| 3 | Mac → WezTerm → ssh Windows → `wsl` | Unreliable | Windows' **ConPTY** sits in the middle |
| 4 | Mac → WezTerm → **ssh straight into WSL** | Yes | Windows is out of the path entirely |

**Row 3 is the trap and row 4 is the answer.** Reaching WSL by SSHing to Windows and then
running `wsl.exe` puts ConPTY — the Windows console layer — between WezTerm and the program
drawing the image. Rather than characterise exactly what ConPTY does to a 200KB base64
escape sequence, skip it: give the WSL distro its own sshd and connect to it directly. See
[wsl-autostart](https://github.com/Gin111191/wsl-autostart) for keeping that distro running
so there is something to SSH into.

Plain SSH is not itself a problem. It is a transparent byte pipe; the escape sequence
arrives intact and the terminal draws it. Only ConPTY is.

## What this repo installs

| | What it is | Used by |
|---|---|---|
| `chafa` | draws an image in the shell, picking the protocol itself | you, at the prompt |
| `imagemagick` | provides `magick` | Neovim's snacks.image |

Neither is a daemon and neither has config. `install.sh` picks brew / apt / paru / pacman,
installs both under whichever it finds, and then runs the probe.

## The three places an image can appear

### 1. The shell — `chafa`

```sh
chafa picture.png
```

That is the whole thing. `chafa` works out which protocol the terminal supports and falls
back to coloured Unicode block characters when there is none, so it always prints
*something* — which makes "did it work?" ambiguous. To be sure:

```sh
chafa -f symbols picture.png   # force the fallback, then compare
```

A real protocol looks like a photograph. The fallback looks like a mosaic.

### 2. Neovim — snacks.image

Lives in [nvim-config](https://github.com/Gin111191/nvim-config), not here —
`lua/plugins/image.lua`. It renders through the Kitty protocol and shells out to `magick`,
which is why this repo installs ImageMagick.

Deliberately **not** `3rd/image.nvim`: that one wants luarocks and the `magick` Lua rock,
and on a machine without luarocks lazy.nvim retries the build until it gives up with
"Too many rounds of missing plugins". snacks needs only the binary.

```sh
nvim picture.png       # the picture, not a screen of NUL bytes
:checkhealth snacks    # names whichever piece is missing
```

### 3. Claude Code — already built in

Nothing to install. The binary carries a Kitty-graphics renderer. From the string table of
`claude` 2.1.267:

```
_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA   the Kitty support query it sends on startup
_Ga=T,t=f,f=100,q=2;               display a PNG named by file path
_Ga=T,t=d,f=100,q=2;               display a PNG sent inline as base64
\ghosttywezterm                    the terminal allowlist
 (image)                           the placeholder when none of the above applies
```

Two details worth knowing. It **probes** the terminal rather than trusting `$TERM_PROGRAM`,
so it is not fooled by SSH (see below). And the `t=d` form sends the pixels in-band, so it
needs no shared filesystem between the terminal and the machine Claude Code runs on — which
is exactly the SSH case.

Seeing ` (image)` instead of a picture means the terminal is not on that allowlist. On
Windows that usually means conhost.

## tmux

tmux multiplexes the byte stream and will not forward an escape sequence it does not
recognise. One line:

```tmux
set -g allow-passthrough on
```

Already set in [tmux-config](https://github.com/Gin111191/tmux-config). A **running** tmux
server keeps the settings it started with, so after adding it either reload
(`prefix` + `r`) or `tmux kill-server`.

Always test outside tmux first, then inside. That way a failure tells you which layer broke.

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
your own shell, not through a pipe, `ssh host cmd`, or an agent's tool call.

Then the three actual checks:

```sh
chafa picture.png
nvim picture.png
claude          # then ask it to look at picture.png
```

`/usr/share/pixmaps/ubuntu-logo-text.png` exists on any Ubuntu, if you need a file to test
with.

## When it does not work

| Symptom | Cause | Fix |
|---|---|---|
| `imgprobe.sh` prints `<silence>` | the terminal ignored the query | it has no image protocol — conhost, `screen`, most CI shells |
| Everything is coloured blocks | no protocol, `chafa` fell back to symbols | change terminal; nothing else here will help |
| Works locally, blocks over SSH | `chafa` could not identify the terminal | `chafa -f kitty` — and see below |
| Works outside tmux, not inside | `allow-passthrough` missing, or a stale server | `tmux kill-server` and reconnect |
| Neovim shows NUL bytes | `magick` missing, or snacks not loaded | `:checkhealth snacks` |
| Claude Code shows ` (image)` | terminal not on its allowlist | use WezTerm, Kitty or Ghostty |
| A picture appears, then vanishes on scroll | normal — the protocols do not survive reflow | redraw it |

### The SSH environment gap

SSH forwards `TERM`. It does **not** forward `TERM_PROGRAM`. So on the far side of an SSH
connection, anything that identifies a terminal by that variable sees nothing:

```sh
echo $TERM_PROGRAM     # "WezTerm" locally, empty over ssh
```

Claude Code and `imgprobe.sh` both probe the terminal instead, so neither is affected. If
`chafa` alone degrades to symbols over SSH, that gap is why. Two fixes — force the format:

```sh
chafa -f kitty picture.png
```

or carry the variable across, which takes an edit on each end:

```sh
# ~/.ssh/config, on the machine you type on
Host wsl
    SetEnv TERM_PROGRAM=WezTerm

# /etc/ssh/sshd_config.d/*.conf, on the machine you connect to
AcceptEnv TERM_PROGRAM
```

Forcing the format is one flag and no root, so try that first.

## Related

- [wsl-autostart](https://github.com/Gin111191/wsl-autostart) — keep the WSL distro up so row 4 has something to reach
- [tmux-config](https://github.com/Gin111191/tmux-config) — where `allow-passthrough` lives
- [nvim-config](https://github.com/Gin111191/nvim-config) — where the Neovim half lives
