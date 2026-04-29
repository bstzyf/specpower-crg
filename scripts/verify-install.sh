#!/usr/bin/env bash
#
# verify-install.sh — acceptance checks for the AI Workflow Kit (spcrg prefix).
#
# Implements §14.1–14.3 from the implementation handbook:
#   1. All nine commands exist.
#   2. All three gate scripts exist and are executable.
#   3. Commands that need an embedded gate actually embed it.
#
# Exits non-zero on any failure and prints a summary.

set -euo pipefail

root="${1:-.}"
cd "$root"

fail=0
note() { printf "  %s\n" "$*"; }
ok()   { printf "  \033[32mok\033[0m  %s\n" "$*"; }
bad()  { printf "  \033[31mfail\033[0m %s\n" "$*"; fail=$((fail+1)); }

echo "[1/5] commands exist"
required_commands=(
  .claude/commands/spcrg-start.md
  .claude/commands/spcrg-plan.md
  .claude/commands/spcrg-dev.md
  .claude/commands/spcrg-review.md
  .claude/commands/spcrg-archive.md
  .claude/commands/spcrg-bugfix.md
  .claude/commands/spcrg-hotfix.md
  .claude/commands/spcrg-refactor.md
  .claude/commands/spcrg-audit.md
  .claude/commands/spcrg-loop.md
)
for f in "${required_commands[@]}"; do
  if [ -f "$f" ]; then ok "$f"; else bad "missing $f"; fi
done

echo ""
echo "[2/5] gate scripts exist and are executable"
required_scripts=(
  scripts/check-crg-evidence.sh
  scripts/check-openspec-gate.sh
  scripts/detect-change-id.sh
  scripts/check-v5-review.sh
  scripts/check-command-protocols.sh
)
for f in "${required_scripts[@]}"; do
  if [ ! -f "$f" ]; then
    bad "missing $f"
  elif [ ! -x "$f" ]; then
    bad "$f is not executable (run: chmod +x $f)"
  else
    ok "$f"
  fi
done

echo ""
echo "[3/5] commands embed gate script calls"
gated_commands=(
  .claude/commands/spcrg-plan.md
  .claude/commands/spcrg-dev.md
  .claude/commands/spcrg-review.md
  .claude/commands/spcrg-archive.md
  .claude/commands/spcrg-audit.md
  .claude/commands/spcrg-loop.md
)
for f in "${gated_commands[@]}"; do
  if [ ! -f "$f" ]; then
    bad "$f missing (cannot check gate header)"
    continue
  fi
  if grep -q "check-openspec-gate.sh" "$f" && grep -q "check-crg-evidence.sh" "$f"; then
    ok "$f embeds both gate scripts"
  else
    bad "$f does not embed both gate scripts"
  fi
done

echo ""
echo "[4/5] spcrg-start.md runs gate after artifacts"
if [ -f .claude/commands/spcrg-start.md ]; then
  if grep -q "check-openspec-gate.sh" .claude/commands/spcrg-start.md \
     && grep -q "check-crg-evidence.sh" .claude/commands/spcrg-start.md; then
    ok ".claude/commands/spcrg-start.md embeds gate scripts at the end"
  else
    bad "spcrg-start.md must embed both gate scripts"
  fi
fi

echo ""
echo "[5/5] command files contain V5 protocol keywords"
if [ -x "$root/scripts/check-command-protocols.sh" ]; then
  if "$root/scripts/check-command-protocols.sh" "$root/.claude/commands" >/dev/null 2>&1; then
    ok "V5 protocol keywords present in all commands"
  else
    bad "V5 protocol keywords missing (run: scripts/check-command-protocols.sh .claude/commands)"
  fi
else
  bad "scripts/check-command-protocols.sh not found or not executable"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  printf "\033[32mAll acceptance checks passed.\033[0m\n"
  exit 0
else
  printf "\033[31m%s acceptance check(s) failed.\033[0m\n" "$fail"
  exit 1
fi
