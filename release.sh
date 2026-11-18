#!/usr/bin/env bash
# Build distributable archives for fm1-chiptest.
#
# Produces, in ./dist/:
#   fm1-chiptest-<VERSION>-source.tar.gz          script + README + LICENSE (auto-downloads the emulator)
#   fm1-chiptest-<VERSION>-<os>-<arch>.tar.gz     ... with the emulator binaries bundled (offline)
#   SHA256SUMS.txt
#
# The bundled archives fetch the prebuilt fm1-emu / fm1-live binaries from the
# fm1-emu GitHub releases, so they run without a network connection.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-1.0.0}"
EMU_VERSION="0.5.1"
EMU_BASE="https://github.com/joakimeriksson/fm1-emu/releases/download/v${EMU_VERSION}"

# platform -> archive suffix (space separated: name ext)
PLATFORMS=(
  "macos-arm64 tar.gz"
  "linux-arm64 tar.gz"
  "linux-x86_64 tar.gz"
  "windows-x86_64 zip"
)

rm -rf dist stage
mkdir -p dist stage

cp fm1-chiptest README.md LICENSE stage/

# download + bundle the emulator for each platform
for entry in "${PLATFORMS[@]}"; do
  set -- $entry; plat=$1; ext=$2
  name="fm1-emu-${EMU_VERSION}-${plat}"
  bin="stage/bin/${name}"
  mkdir -p "$bin"
  arc="stage/${name}.${ext}"
  echo "fetching ${EMU_BASE}/${name}.${ext}"
  curl -fL --retry 2 -o "$arc" "${EMU_BASE}/${name}.${ext}"
  if [ "$ext" = "zip" ]; then
    # the Windows zip stores paths with backslashes; unzip warns but extracts fine
    unzip -qo "$arc" -d "$bin" || true
    find "$bin" -type f \( -name 'fm1-emu' -o -name 'fm1-emu.exe' \
                             -o -name 'fm1-live' -o -name 'fm1-live.exe' \) \
      -exec mv -f {} "$bin/" \;
    find "$bin" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
  else
    tar -xzf "$arc" -C "$bin" --strip-components=1
  fi
  rm -f "$arc"
  chmod +x "$bin/"fm1-emu* "$bin/"fm1-live* 2>/dev/null || true
  # per-platform archive (script + README + LICENSE + this platform's binaries)
  pkg="fm1-chiptest-${VERSION}-${plat}"
  mkdir -p "stage/pkg-${plat}/bin"
  cp -R fm1-chiptest README.md LICENSE "stage/pkg-${plat}/"
  cp -R "$bin/." "stage/pkg-${plat}/bin/"
  (cd stage && tar -czf "../dist/${pkg}.tar.gz" "pkg-${plat}")
done

# source-only archive
mkdir -p stage/source
cp fm1-chiptest README.md LICENSE stage/source/
(cd stage && tar -czf "../dist/fm1-chiptest-${VERSION}-source.tar.gz" source)

# checksums
(cd dist && shasum -a 256 fm1-chiptest-*.tar.gz > SHA256SUMS.txt)

echo
echo "built in dist/:"
ls -la dist/
