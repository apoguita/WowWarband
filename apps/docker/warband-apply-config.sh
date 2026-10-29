#!/usr/bin/env bash
#
# Warband config replication for the container stack.
#
# The tracked deltas in data/configs are written into the installed configuration directory,
# exactly as Warband-Configs.ps1 -Action apply does on a Windows install: a tracked key that
# exists is rewritten in place, a tracked key that is missing is appended with a note, and
# every other line of the file stays untouched. The compose override runs this as the one-shot
# `warband-config` service before the server containers start.
#
# usage: warband-apply-config.sh [--configs DIR] [--conf-dir DIR]
#
#   --configs   the tracked delta tree (default /warband/configs, the checkout's data/configs)
#   --conf-dir  the installed configuration tree (default /azerothcore/env/dist/etc)
#
# Machine- and container-specific keys are never replicated: DataDir and the *DatabaseInfo
# credentials describe one machine, and BindIP must stay 0.0.0.0 inside a container for the
# published ports to reach it.
#
set -euo pipefail

CONFIGS_DIR="${WARBAND_CONFIGS_DIR:-/warband/configs}"
CONF_DIR="${CONF_DIR:-/azerothcore/env/dist/etc}"
REF_ETC="${WARBAND_REF_ETC:-/azerothcore/env/ref/etc}"

SKIP_KEYS=" BindIP DataDir LoginDatabaseInfo WorldDatabaseInfo CharacterDatabaseInfo SOAP.Password "

usage() {
  sed -n '2,20p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configs)
      [[ $# -ge 2 ]] || { echo "missing value for --configs" >&2; exit 2; }
      CONFIGS_DIR="$2"
      shift 2
      ;;
    --conf-dir)
      [[ $# -ge 2 ]] || { echo "missing value for --conf-dir" >&2; exit 2; }
      CONF_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# The tracked tree is a "key = value" delta set, one file per installed config, mirroring the
# installed layout (worldserver.conf, authserver.conf, modules/<name>.conf).
write_pairs() { # tracked conf -> key<TAB>value lines on stdout
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      line = $0
      eq = index(line, "=")
      if (eq == 0) next
      key = substr(line, 1, eq - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key !~ /^[A-Za-z0-9_.]+$/) next
      value = substr(line, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print key "\t" value
    }' "$1"
}

# Rewrites the tracked keys in an installed file. A key that is present is replaced on its own
# line (or left alone when it already holds the tracked value, so padding alone never counts as
# drift); a key that is absent is appended under a note saying where it came from. Exit status 3
# from awk means "key absent", which is not an error.
patch_file() { # installed conf, pairs file
  local target="$1" pairs="$2" key value out rc
  while IFS=$'\t' read -r key value; do
    [[ -z "$key" ]] && continue
    if [[ "$SKIP_KEYS" == *" $key "* ]]; then
      echo "  $(basename "$target") : $key left as is (not a Warband decision in a container)"
      continue
    fi
    out="$(mktemp)"
    rc=0
    awk -v k="$key" -v v="$value" '
      BEGIN { pattern = "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*"; found = 0 }
      {
        if (!found && $0 ~ pattern) {
          rest = $0
          sub(pattern, "", rest)
          sub(/[[:space:]]+$/, "", rest)
          if (rest == v) print $0
          else print k " = " v
          found = 1
        } else {
          print $0
        }
      }
      END { if (!found) exit 3 }' "$target" > "$out" || rc=$?
    if [[ $rc -eq 3 ]]; then
      printf '\n# Set by Warband (data/configs) - see Warband-Configs.ps1\n%s = %s\n' "$key" "$value" >> "$out"
      echo "  $(basename "$target") : $key = $value (added)"
    elif [[ $rc -ne 0 ]]; then
      rm -f "$out"
      echo "failed to patch $target for $key" >&2
      return 1
    else
      echo "  $(basename "$target") : $key = $value"
    fi
    mv "$out" "$target"
  done < "$pairs"
}

if [[ ! -d "$CONFIGS_DIR" ]]; then
  echo "No tracked configuration at $CONFIGS_DIR - nothing to apply."
  exit 0
fi

# The server images seed the install directory from their reference tree on start; this service
# runs first, so it performs the same seeding before patching anything.
if [[ -d "$REF_ETC" ]]; then
  mkdir -p "$CONF_DIR"
  cp -rn "$REF_ETC/." "$CONF_DIR/" 2>/dev/null || true
fi
mkdir -p "$CONF_DIR/modules"

tracked=()
while IFS= read -r tracked_file; do
  tracked+=("$tracked_file")
done < <(find "$CONFIGS_DIR" -type f -name '*.conf' | sort)

status=0
for tracked_file in "${tracked[@]}"; do
  relative="${tracked_file#"$CONFIGS_DIR"/}"
  target="$CONF_DIR/$relative"
  if [[ ! -f "$target" ]]; then
    if [[ -f "$target.dist" ]]; then
      cp -v "$target.dist" "$target"
    else
      echo "skipped $relative (no installed file and no $relative.dist)"
      continue
    fi
  fi
  pairs="$(mktemp)"
  write_pairs "$tracked_file" > "$pairs"
  if [[ -s "$pairs" ]]; then
    echo "applying $relative"
    patch_file "$target" "$pairs" || status=1
  fi
  rm -f "$pairs"
done

exit "$status"
