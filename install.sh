#!/usr/bin/env bash
#
# Install the skills in this repo into your Claude Code personal skills folder.
#
#   ./install.sh                    symlink every skill
#   ./install.sh luz-parasha        symlink only the named skill(s)
#   ./install.sh --copy             copy instead of symlink (no auto-updates)
#   ./install.sh --force            overwrite existing entries
#   ./install.sh --uninstall        remove this repo's skills from the dest
#   ./install.sh --list             show what's in the repo and its status
#   ./install.sh --dest DIR         install somewhere else (default ~/.claude/skills)
#
# Symlink mode is the default: `git pull` in this repo then updates every
# installed skill in place.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/skills"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

MODE="link"
ACTION="install"
FORCE=0
SELECTED=()

# ---------- colours (disabled when not a tty) ----------
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

die()  { printf '%serror:%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }
info() { printf '%s\n' "$1"; }

usage() {
  cat <<'EOF'
Install the skills in this repo into your Claude Code personal skills folder.

  ./install.sh                 symlink every skill
  ./install.sh <name>...       symlink only the named skill(s)
  ./install.sh --copy          copy instead of symlink (no auto-updates)
  ./install.sh --force         overwrite entries that already exist
  ./install.sh --uninstall     remove this repo's skills from the dest
  ./install.sh --list          show every skill and whether it's installed
  ./install.sh --dest DIR      install elsewhere (default ~/.claude/skills)

Symlink mode is the default: `git pull` in this repo then updates every
installed skill in place. Restart Claude Code afterwards so it picks up a
newly created skills directory.
EOF
  exit 0
}

# ---------- args ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --copy)       MODE="copy" ;;
    --force|-f)   FORCE=1 ;;
    --uninstall)  ACTION="uninstall" ;;
    --list|-l)    ACTION="list" ;;
    --dest)       shift; [ $# -gt 0 ] || die "--dest needs a directory"; DEST_DIR="$1" ;;
    --help|-h)    usage ;;
    -*)           die "unknown flag: $1" ;;
    *)            SELECTED+=("$1") ;;
  esac
  shift
done

[ -d "$SRC_DIR" ] || die "no skills/ directory found at $SRC_DIR"

# ---------- discover skills (a skill = a directory containing SKILL.md) ----------
ALL_SKILLS=()
for dir in "$SRC_DIR"/*/; do
  [ -f "${dir}SKILL.md" ] || continue
  ALL_SKILLS+=("$(basename "$dir")")
done

[ ${#ALL_SKILLS[@]} -gt 0 ] || die "no skills found in $SRC_DIR (each skill needs its own dir with a SKILL.md)"

# ---------- resolve which skills to act on ----------
TARGETS=()
if [ ${#SELECTED[@]} -eq 0 ]; then
  TARGETS=("${ALL_SKILLS[@]}")
else
  for want in "${SELECTED[@]}"; do
    found=0
    for have in "${ALL_SKILLS[@]}"; do
      [ "$want" = "$have" ] && { TARGETS+=("$want"); found=1; break; }
    done
    [ $found -eq 1 ] || die "no such skill in this repo: $want"
  done
fi

# ---------- list ----------
if [ "$ACTION" = "list" ]; then
  printf '%sskills in %s%s\n\n' "$BOLD" "$REPO_DIR" "$RESET"
  for name in "${ALL_SKILLS[@]}"; do
    target="$DEST_DIR/$name"
    if [ -L "$target" ]; then
      status="${GREEN}linked${RESET} ${DIM}-> $(readlink "$target")${RESET}"
    elif [ -d "$target" ]; then
      status="${YELLOW}copied (or unrelated dir)${RESET}"
    else
      status="${DIM}not installed${RESET}"
    fi
    printf '  %-28s %s\n' "$name" "$status"
  done
  printf '\n%sdest: %s%s\n' "$DIM" "$DEST_DIR" "$RESET"
  exit 0
fi

# ---------- uninstall ----------
if [ "$ACTION" = "uninstall" ]; then
  removed=0
  for name in "${TARGETS[@]}"; do
    target="$DEST_DIR/$name"
    if [ -L "$target" ]; then
      link_dest="$(readlink "$target")"
      case "$link_dest" in
        "$SRC_DIR"/*) rm "$target"; info "  removed link  $name"; removed=$((removed+1)) ;;
        *)            info "  ${YELLOW}skipped${RESET}       $name (symlink points outside this repo)" ;;
      esac
    elif [ -d "$target" ]; then
      if [ $FORCE -eq 1 ]; then
        rm -rf "$target"; info "  removed dir   $name"; removed=$((removed+1))
      else
        info "  ${YELLOW}skipped${RESET}       $name (real directory - rerun with --force to delete)"
      fi
    fi
  done
  info ""
  info "removed $removed skill(s) from $DEST_DIR"
  exit 0
fi

# ---------- install ----------
mkdir -p "$DEST_DIR"

installed=0
skipped=0
for name in "${TARGETS[@]}"; do
  src="$SRC_DIR/$name"
  target="$DEST_DIR/$name"

  if [ -e "$target" ] || [ -L "$target" ]; then
    # Already pointing at this repo? Nothing to do.
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
      info "  ${DIM}already linked${RESET}  $name"
      continue
    fi
    if [ $FORCE -eq 1 ]; then
      rm -rf "$target"
    else
      info "  ${YELLOW}skipped${RESET}         $name (already exists - rerun with --force to replace)"
      skipped=$((skipped+1))
      continue
    fi
  fi

  if [ "$MODE" = "copy" ]; then
    cp -R "$src" "$target"
    info "  ${GREEN}copied${RESET}          $name"
  else
    ln -s "$src" "$target"
    info "  ${GREEN}linked${RESET}          $name"
  fi
  installed=$((installed+1))
done

info ""
info "${BOLD}$installed installed${RESET}, $skipped skipped  ->  $DEST_DIR"
if [ "$MODE" = "link" ] && [ $installed -gt 0 ]; then
  info "${DIM}symlinked: 'git pull' in this repo updates them in place${RESET}"
fi
info ""
info "Restart Claude Code (or start a new session) so it picks up the new"
info "skills directory, then run /skills to confirm they're listed."
