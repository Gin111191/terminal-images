#!/bin/sh
# Ask the terminal itself which image protocols it implements.
# Run it in each scenario; outside tmux first, then inside.
# ponytail: 0.4s fixed wait instead of a select() loop — a terminal that answers
# slower than that reads as "no". Raise WAIT if you are on a laggy SSH link.
WAIT=0.4

[ -t 0 ] && [ -t 1 ] || { echo "needs a real terminal, not a pipe"; exit 1; }

ask() {  # ask <escape-to-send> ; prints whatever the terminal replies
    old=$(stty -g)
    stty raw -echo min 0 time 0
    printf '%b' "$1" > /dev/tty
    sleep "$WAIT"
    reply=$(dd bs=1024 count=1 2>/dev/null < /dev/tty)
    stty "$old"
    printf '%s' "$reply" | tr -d '\033\a' | tr '\0' '?'
}

echo "TERM=$TERM  TERM_PROGRAM=${TERM_PROGRAM:-none}  TMUX=${TMUX:+yes}${TMUX:-no}"

da1=$(ask '\033[c')
echo "DA1 reply: ${da1:-<silence>}"
case "$da1" in *";4;"*|*";4c"*) echo "  sixel:          YES" ;; *) echo "  sixel:          no" ;; esac

kitty=$(ask '\033_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\033\\\033[c')
case "$kitty" in *"Gi=31;OK"*) echo "  kitty graphics: YES" ;; *) echo "  kitty graphics: no" ;; esac

case "${TERM_PROGRAM}${WEZTERM_PANE:+WezTerm}" in
    *WezTerm*|*iTerm*) echo "  iterm2 inline:  YES (by terminal identity)" ;;
    *)                 echo "  iterm2 inline:  unknown — no query exists for it" ;;
esac
