#!/usr/bin/env bash
set -e

export DEVKITPRO=/opt/devkitpro
export RENPY_VER=8.3.4
PYTHON_VER=3.14

# ─── Activate venv created by setup.bash ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "ERROR: Venv not found at $VENV_DIR"
    echo "       Please run setup.bash first."
    exit 1
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
export PATH="$VENV_DIR/bin:$PATH"
export RENPY_CYTHON="$(which cython 2>/dev/null || echo "$VENV_DIR/bin/cython")"

echo ">>> Building C extensions using Cython: $RENPY_CYTHON"

echo ">>> Using Python: $(which python) — $(python --version)"
echo ">>> Using Pip:    $(which pip)"

# ─── Build pygame_sdl2 C extensions ──────────────────────────────────────────
pushd pygame_sdl2-source
rm -rf gen gen-static
python setup.py build || true
PYGAME_SDL2_STATIC=1 python setup.py build || true
popd

# ─── Build Ren'Py C extensions ───────────────────────────────────────────────
pushd renpy-source/module
rm -rf gen gen-static
RENPY_DEPS_INSTALL=/usr/lib/x86_64-linux-gnu:/usr:/usr/local python setup.py build || true
RENPY_DEPS_INSTALL=/usr/lib/x86_64-linux-gnu:/usr:/usr/local RENPY_STATIC=1 python setup.py build || true
popd

# ─── Install pygame_sdl2 into the venv ───────────────────────────────────────
pushd pygame_sdl2-source
python setup.py build
python setup.py install_headers
python setup.py install
popd

# ─── Install Ren'Py module into the venv ─────────────────────────────────────
pushd renpy-source/module
RENPY_DEPS_INSTALL=/usr/lib/x86_64-linux-gnu:/usr:/usr/local python setup.py build
RENPY_DEPS_INSTALL=/usr/lib/x86_64-linux-gnu:/usr:/usr/local python setup.py install
popd

# ─── Link generated C sources for CMake build ────────────────────────────────
bash link_sources.bash

export PREFIXARCHIVE=$(realpath renpy-switch-modules.tar.gz)

rm -rf build-switch
mkdir build-switch
pushd build-switch
mkdir local_prefix
export LOCAL_PREFIX=$(realpath local_prefix)
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .
mkdir -p $LOCAL_PREFIX/lib
cp librenpy-switch-modules.a $LOCAL_PREFIX/lib/librenpy-switch-modules.a
popd

tar -czvf $PREFIXARCHIVE -C $LOCAL_PREFIX .
tar -xf renpy-switch-modules.tar.gz -C $DEVKITPRO/portlibs/switch
rm renpy-switch-modules.tar.gz
rm -rf build-switch

source /opt/devkitpro/switchvars.sh

# ─── Cross-compile Switch executable ─────────────────────────────────────────
pushd switch
rm -rf build
mkdir build
pushd build
cmake ..
make
popd
popd

mkdir -p ./raw/switch/exefs
mv ./switch/build/renpy-switch.nso ./raw/switch/exefs/main
rm -rf switch include source pygame_sdl2-source

# ─── Assemble Ren'Py project tree ────────────────────────────────────────────
rm -rf renpy_clear
mkdir renpy_clear
cp ./renpy_sdk/*/renpy.sh ./renpy_clear/renpy.sh
cp -r ./renpy_sdk/*/lib ./renpy_clear/lib
mkdir ./renpy_clear/game
cp -r ./renpy-source/module ./renpy_clear/module
cp -r ./renpy-source/renpy ./renpy_clear/renpy
cp ./renpy-source/renpy.py ./renpy_clear/renpy.py
mv ./script.rpy ./renpy_clear/game/script.rpy
cp ./renpy_sdk/*/*.exe ./renpy_clear/ || true
rm -rf renpy-source renpy_sdk ./renpy_clear/lib/*mac*

pushd renpy_clear
./renpy.sh . compile
find ./renpy/ -regex ".*\.\(pxd\|pyx\|rpym\|pxi\)" -delete
popd

# ─── Generate private archive ────────────────────────────────────────────────
rm -rf private
mkdir private
mkdir private/lib
cp -r renpy_clear/renpy private/renpy
cp -r renpy_clear/lib/python$PYTHON_VER/ private/lib/
cp renpy_clear/renpy.py private/main.py
rm -rf private/renpy/common
python generate_private.py
rm -rf private

# ─── Assemble final Switch romfs layout ──────────────────────────────────────
mkdir -p ./raw/switch/romfs/Contents/renpy
mkdir -p ./raw/lib
cp -r ./renpy_clear/renpy/common ./raw/switch/romfs/Contents/renpy/
cp ./renpy_clear/renpy.py ./raw/switch/romfs/Contents/
cp -r ./renpy_clear/lib/python$PYTHON_VER/. ./raw/lib
cp -r ./renpy_clear/renpy ./raw/lib
rm -rf ./raw/lib/renpy/common/
7z a -tzip ./raw/switch/romfs/Contents/lib.zip ./raw/lib/*
rm -rf ./raw/lib
rm -rf ./renpy_clear/game
mv ./renpy_clear/ ./raw/

echo ">>> build.bash complete. Output is in ./raw/"
