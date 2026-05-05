#!/usr/bin/env bash
#
# scripts/build-custom.sh
# Build & deploy the custom Double Commander fork.
#
# Refuses to run unless HEAD is on `custom/main` so we never accidentally
# build from a feature branch and ship an exe that's missing other features.
#
# Usage:
#   scripts/build-custom.sh                # build main exe + deploy
#   scripts/build-custom.sh --full         # also rebuild components/plugins
#   scripts/build-custom.sh --no-deploy    # build only, skip copy
#
# Env overrides:
#   LAZBUILD   path to lazbuild.exe          (default: C:/lazarus/lazbuild.exe)
#   FPC        path to fpc.exe               (default: C:/lazarus/fpc/3.2.2/bin/x86_64-win64/fpc.exe)
#   LAZDIR     Lazarus install dir           (default: C:/lazarus)
#   DEPLOY     destination exe path          (default: E:/tools/doublecmd/doublecmd.exe)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

LAZBUILD="${LAZBUILD:-C:/lazarus/lazbuild.exe}"
FPC="${FPC:-C:/lazarus/fpc/3.2.2/bin/x86_64-win64/fpc.exe}"
LAZDIR="${LAZDIR:-C:/lazarus}"
DEPLOY="${DEPLOY:-E:/tools/doublecmd/doublecmd.exe}"
OPTS="--lazarusdir=$LAZDIR --compiler=$FPC"

# ---------- args ----------
FULL=0
DEPLOY_ENABLED=1
for arg in "$@"; do
  case "$arg" in
    --full)       FULL=1 ;;
    --no-deploy)  DEPLOY_ENABLED=0 ;;
    -h|--help)
      sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $arg" >&2
      echo "       try --help" >&2
      exit 2
      ;;
  esac
done

# ---------- guard 1: branch must be custom/main ----------
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)"
if [ "$BRANCH" != "custom/main" ]; then
  echo "ERROR: must build on custom/main, but HEAD is on '$BRANCH'." >&2
  echo "       Building from a feature branch produces an exe missing all other features." >&2
  echo "       Fix:  git checkout custom/main && git merge $BRANCH" >&2
  exit 1
fi

# ---------- guard 2: tools exist ----------
if [ ! -x "$LAZBUILD" ]; then
  echo "ERROR: lazbuild not found at: $LAZBUILD" >&2
  echo "       set LAZBUILD env var to override." >&2
  exit 1
fi

# ---------- guard 3: working tree (warn only) ----------
if ! git diff-index --quiet HEAD --; then
  echo "WARN: working tree has uncommitted changes (build will use what's on disk)" >&2
fi

# ---------- info ----------
HEAD_HASH="$(git rev-parse --short HEAD)"
HEAD_SUBJECT="$(git log -1 --pretty=%s)"
echo "==> branch:  $BRANCH @ $HEAD_HASH"
echo "==> commit:  $HEAD_SUBJECT"
echo "==> mode:    $([ "$FULL" = 1 ] && echo full || echo 'main-exe-only')"
echo "==> deploy:  $([ "$DEPLOY_ENABLED" = 1 ] && echo "$DEPLOY" || echo 'skipped')"

# ---------- build components / plugins (full only) ----------
if [ "$FULL" = 1 ]; then
  echo "==> components"
  for pkg in \
    components/chsdet/chsdet.lpk \
    components/multithreadprocs/multithreadprocslaz.lpk \
    components/kascrypt/kascrypt.lpk \
    components/doublecmd/doublecmd_common.lpk \
    components/Image32/Image32.lpk \
    components/KASToolBar/kascomp.lpk \
    components/viewer/viewerpackage.lpk \
    components/gifview/gifview.lpk \
    components/synunihighlighter/synuni.lpk \
    components/virtualterminal/virtualterminal.lpk
  do
    echo "    -- $pkg"
    "$LAZBUILD" $OPTS "$pkg"
  done

  echo "==> plugins"
  for pkg in \
    plugins/wcx/base64/src/base64wcx.lpi \
    plugins/wcx/deb/src/deb.lpi \
    plugins/wcx/rpm/src/rpm.lpi \
    plugins/wcx/sevenzip/src/sevenzipwcx.lpi \
    plugins/wcx/unrar/src/unrar.lpi \
    plugins/wcx/zip/src/zip.lpi \
    plugins/wdx/rpm_wdx/src/rpm_wdx.lpi \
    plugins/wdx/deb_wdx/src/deb_wdx.lpi \
    plugins/wdx/audioinfo/src/AudioInfo.lpi \
    plugins/wfx/ftp/src/ftp.lpi \
    plugins/wlx/wmp/src/wmp.lpi \
    plugins/wlx/preview/src/preview.lpi \
    plugins/wlx/richview/src/richview.lpi
  do
    echo "    -- $pkg"
    "$LAZBUILD" $OPTS "$pkg"
  done
fi

# ---------- build main exe ----------
echo "==> main executable (release)"
"$LAZBUILD" $OPTS src/doublecmd.lpi --bm=release

if [ ! -f doublecmd.exe ]; then
  echo "ERROR: build finished but doublecmd.exe is missing" >&2
  exit 1
fi

SIZE="$(stat -c%s doublecmd.exe)"
echo "==> built doublecmd.exe ($SIZE bytes)"

# ---------- deploy ----------
if [ "$DEPLOY_ENABLED" = 1 ]; then
  DEPLOY_DIR="$(dirname "$DEPLOY")"
  if [ ! -d "$DEPLOY_DIR" ]; then
    echo "ERROR: deploy directory does not exist: $DEPLOY_DIR" >&2
    exit 1
  fi

  if ! cp -f doublecmd.exe "$DEPLOY" 2>/dev/null; then
    echo "ERROR: copy to '$DEPLOY' failed." >&2
    echo "       The target is probably running. Close it (or run, in PowerShell):" >&2
    echo "         Stop-Process -Name doublecmd -Force" >&2
    echo "       then re-run this script with --no-deploy && cp doublecmd.exe '$DEPLOY'" >&2
    exit 1
  fi
  echo "==> deployed to $DEPLOY"
fi

echo "OK"
