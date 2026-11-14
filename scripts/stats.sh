#!/usr/bin/env bash
# Download and traffic numbers for Levels, read from the GitHub API.
# Needs the GitHub CLI logged in with push access to the repos (traffic data is private).
#
#   scripts/stats.sh                       readable report
#   scripts/stats.sh --csv >> ~/levels-stats.csv
#       one line for a log, columns:
#       date,zip,curl,brew_or_manual,tap_clones_14d,tap_uniques_14d,repo_views_14d,repo_uniques_14d
#
# How to read the numbers:
# - Levels.zip counts every download: Homebrew, the curl script and manual downloads.
# - Levels.zip.sha256 is fetched only by install.sh, so it is roughly the number of curl installs.
#   The difference is Homebrew plus manual downloads; GitHub can't tell those two apart.
# - Clones of the tap repo roughly follow new Homebrew users (the first `brew install
#   rafaelisdev/tap/levels` clones it). Homebrew publishes no analytics for third-party taps.
# - GitHub keeps traffic for the last 14 days only. Log --csv regularly to keep a history.
# - Our own test installs are counted too.
set -euo pipefail

REPO="${LEVELS_REPO:-rafaelisdev/levels}"
TAP="${LEVELS_TAP:-rafaelisdev/homebrew-tap}"

command -v gh >/dev/null || { echo "Needs the GitHub CLI: brew install gh" >&2; exit 1; }

# Per release: downloads of the .zip and of its .zip.sha256 (older releases were VolumeMixer.zip).
SUMS='[.[] | {tag: .tag_name, date: ((.published_at // "")[0:10]),
  zip: ([.assets[] | select(.name | endswith(".zip")) | .download_count] | add // 0),
  sha: ([.assets[] | select(.name | endswith(".zip.sha256")) | .download_count] | add // 0)}]'

traffic() { # repo, endpoint, jq filter; prints a note instead of failing without push access
  gh api "repos/$1/traffic/$2" --jq "$3" 2>/dev/null || echo "${4:-  (no access to traffic data)}"
}

if [[ "${1:-}" == "--csv" ]]; then
  totals=$(gh api "repos/$REPO/releases?per_page=100" --jq "$SUMS"' | ([.[].zip] | add // 0) as $z | ([.[].sha] | add // 0) as $s | "\($z),\($s),\($z - $s)"')
  tap=$(traffic "$TAP" clones '"\(.count),\(.uniques)"' ",")
  views=$(traffic "$REPO" views '"\(.count),\(.uniques)"' ",")
  echo "$(date +%F),$totals,$tap,$views"
  exit 0
fi

echo "Downloads from GitHub Releases ($REPO, all time)"
gh api "repos/$REPO/releases?per_page=100" --jq '
  def lpad(n): tostring | if (n - length) > 0 then (" " * (n - length)) + . else . end;
  def rpad(n): tostring | if (n - length) > 0 then . + (" " * (n - length)) else . end;
  def row(a; b; c; d; e): "  " + (a | rpad(9)) + (b | rpad(12)) + (c | lpad(6)) + (d | lpad(7)) + (e | lpad(14));
  '"$SUMS"' as $r
  | ([$r[].zip] | add // 0) as $z | ([$r[].sha] | add // 0) as $s
  | row("version"; "date"; "zip"; "curl"; "brew/manual"),
    ($r[] | row(.tag; .date; .zip; .sha; .zip - .sha)),
    row("total"; ""; $z; $s; $z - $s)'

echo
echo "Homebrew tap ($TAP, last 14 days)"
traffic "$TAP" clones '"  clones: \(.count), unique: \(.uniques)",
  (.clones[] | select(.count > 0) | "    \(.timestamp[0:10])  \(.count) (\(.uniques) unique)")'

echo
echo "Repository ($REPO, last 14 days)"
traffic "$REPO" views '"  page views: \(.count), unique: \(.uniques)"'
traffic "$REPO" clones '"  clones: \(.count), unique: \(.uniques)"'
echo "  top referrers:"
traffic "$REPO" popular/referrers 'if length == 0 then "    none yet" else .[] | "    \(.referrer): \(.count) (\(.uniques) unique)" end'

echo
echo "Website visits and referrers: Vercel dashboard, project getlevels, Analytics tab."
