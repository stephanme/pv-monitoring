#!/bin/bash
# check-deploy-wiring.sh - static consistency check for the deploy.sh tree.
#
# Verifies:
#   1. every path a deploy.sh references through $scriptdir actually exists
#      (a deploy.sh pointing at a moved or renamed app aborts the whole run,
#       and a namespace that was moved out can silently stop being deployed)
#   2. every <namespace>/deploy.sh is referenced exactly once by the root deploy.sh
#      (0 = that namespace is never deployed by ./deploy.sh; >1 = deployed twice)
#   3. the root deploy.sh parses
#
# Prints one line per problem, nothing when everything is consistent.
# Exit codes: 0 = consistent, 1 = problems found, 2 = not a repo root.
#
# Usage: ./check-deploy-wiring.sh   (works from any directory)

set -u

scriptdir=$(cd "$(dirname "$0")" && pwd)
cd "$scriptdir" || exit 2

if [ ! -f deploy.sh ]; then
  echo "ERROR: $scriptdir/deploy.sh not found - is this the repo root?"
  exit 2
fi

rc=0

# 1) every $scriptdir-relative target referenced by any deploy.sh must exist
while IFS= read -r s; do
  d=$(dirname "$s")
  refs=$(grep -oE 'scriptdir\}?/[A-Za-z0-9_./-]+' "$s") || true
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    t=${t#scriptdir\}}
    t=${t#scriptdir/}
    t=/${t#/}
    if [ ! -e "$d$t" ]; then
      echo "MISSING: $s -> $d$t"
      rc=1
    fi
  done <<<"$refs"
done < <(find . -name deploy.sh -not -path './.git/*' | sort)

# 2) every <ns>/deploy.sh referenced exactly once by the root deploy.sh
for d in */; do
  d=${d%/}
  [ -f "$d/deploy.sh" ] || continue
  n=$(grep -c -- "$d/deploy.sh" deploy.sh) || true
  if [ "$n" -eq 1 ]; then
    continue
  fi
  if [ "$n" -eq 0 ]; then
    echo "NOT DEPLOYED: $d/ (no '$d/deploy.sh' line in ./deploy.sh)"
  else
    echo "DEPLOYED TWICE: $d/ ($n references in ./deploy.sh)"
  fi
  rc=1
done

# 3) the root script must parse
bash -n deploy.sh || { echo "SYNTAX: deploy.sh"; rc=1; }

exit $rc
