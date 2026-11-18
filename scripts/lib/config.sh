#!/usr/bin/env bash
# The one reader of work/CONFIG.md. A key is a `- key: value` bullet and nothing
# else; a differently labelled line is invisible, not merely wrong.
CONFIG="${CONFIG:-$HOME/work/CONFIG.md}"

cfg() {
  [ -r "$CONFIG" ] || return 0
  sed -n "s/^- $1:[[:space:]]*//p" "$CONFIG" | head -n 1 | sed -e 's/[[:space:]]*$//'
}
