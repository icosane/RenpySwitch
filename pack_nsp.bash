#!/usr/bin/env bash
set -e

# ─── Environment Setup ────────────────────────────────────────────────────────
source /etc/profile.d/devkit-env.sh 2>/dev/null || true
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export PATH="${DEVKITPRO}/tools/bin:$PATH"

# ─── Usage Help ───────────────────────────────────────────────────────────────
show_help() {
    cat << EOF
RenPySwitch NSP Package Generator (Native switch-dev tools)

Usage:
  ./pack_nsp.bash <game_directory> <output.nsp> <title_name> [options]

Required Positional Arguments:
  1. <game_directory>  Path to the Ren'Py game project folder (containing 'game/').
  2. <output.nsp>      Output NSP filename/path (e.g. MyGame.nsp).
  3. <title_name>      Game title name shown on Switch home screen (e.g. "My Game").

Options:
  -t, --title-id ID    Switch Title ID (16 hex chars, default: auto-derived from .exe hash or random fallback).
  -p, --publisher, --developer NAME
                       Publisher/Developer name (default: "RenPy Switch").
  -v, --version VER    Game version string (default: "1.0.0").
  --icon PATH          Path to custom 256x256 PNG/JPG icon (default: .exe icon -> game icon -> libnx default icon).
  -h, --help           Show this help message.

Examples:
  ./pack_nsp.bash /path/to/MyGame MyGame.nsp "My Game Title"
  ./pack_nsp.bash /path/to/MyGame MyGame.nsp "My Game Title" -p "My Studio" -v "1.2.0"
  ./pack_nsp.bash /path/to/MyGame MyGame.nsp "Super Game" --icon my_icon.png
EOF
}

# ─── Flag Parsing ─────────────────────────────────────────────────────────────
GAME_INPUT=""
OUTPUT_NSP=""
TITLE_NAME=""
TITLE_ID="auto"
PUBLISHER="RenPy Switch"
VERSION="1.0.0"
ICON_INPUT=""

POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--input|--game)
            GAME_INPUT="$2"
            shift 2
            ;;
        -o|--out|--output)
            OUTPUT_NSP="$2"
            shift 2
            ;;
        -n|--name|--title-name)
            TITLE_NAME="$2"
            shift 2
            ;;
        -t|--title-id)
            TITLE_ID="$2"
            shift 2
            ;;
        -p|--publisher|--developer)
            PUBLISHER="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --icon)
            ICON_INPUT="$2"
            shift 2
            ;;
        -*)
            echo "ERROR: Unknown option '$1'"
            show_help
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Assign positional arguments
if [ -z "$GAME_INPUT" ] && [ ${#POSITIONAL[@]} -gt 0 ]; then
    GAME_INPUT="${POSITIONAL[0]}"
fi
if [ -z "$OUTPUT_NSP" ] && [ ${#POSITIONAL[@]} -gt 1 ]; then
    OUTPUT_NSP="${POSITIONAL[1]}"
fi
if [ -z "$TITLE_NAME" ] && [ ${#POSITIONAL[@]} -gt 2 ]; then
    TITLE_NAME="${POSITIONAL[2]}"
fi

if [ -z "$GAME_INPUT" ] || [ -z "$OUTPUT_NSP" ] || [ -z "$TITLE_NAME" ]; then
    echo "ERROR: Missing required positional arguments."
    show_help
    exit 1
fi

# ─── Tool Verification ────────────────────────────────────────────────────────
BUILD_ROMFS="$(which build_romfs || true)"
NACPTOOL="$(which nacptool || true)"
BUILD_PFS0="$(which build_pfs0 || true)"

if [ -z "$BUILD_ROMFS" ] || [ -z "$NACPTOOL" ] || [ -z "$BUILD_PFS0" ]; then
    echo "ERROR: Required switch-dev tools ('build_romfs', 'nacptool', 'build_pfs0') not found in PATH or /opt/devkitpro/tools/bin."
    echo "       Please make sure devkitPro / switch-tools are installed."
    exit 1
fi

RAW_MAIN="./raw/switch/exefs/main"
RAW_ROMFS="./raw/switch/romfs"

if [ ! -f "$RAW_MAIN" ] || [ ! -d "$RAW_ROMFS" ]; then
    echo "ERROR: './raw/' framework directory not found or incomplete."
    echo "       Please run 'bash build.bash' first to generate the engine framework."
    exit 1
fi

# Locate the actual 'game' folder and root project folder
if [ -d "$GAME_INPUT/game" ]; then
    PROJECT_ROOT="$GAME_INPUT"
    GAME_DIR="$GAME_INPUT/game"
    DEFAULT_NAME="$(basename "$(cd "$GAME_INPUT" && pwd)")"
elif [ -d "$GAME_INPUT" ] && [ "$(basename "$GAME_INPUT")" = "game" ]; then
    PROJECT_ROOT="$(cd "$GAME_INPUT/.." && pwd)"
    GAME_DIR="$GAME_INPUT"
    DEFAULT_NAME="$(basename "$PROJECT_ROOT")"
else
    echo "ERROR: Could not find a 'game' folder in '$GAME_INPUT'."
    echo "       Please specify a directory that contains a 'game/' folder."
    exit 1
fi

case "$OUTPUT_NSP" in
    *.nsp) ;;
    *) OUTPUT_NSP="${OUTPUT_NSP}.nsp" ;;
esac

# ─── Derive Title ID ──────────────────────────────────────────────────────────
if [ -n "$TITLE_ID" ] && [ "$TITLE_ID" != "auto" ]; then
    FINAL_TITLE_ID="$TITLE_ID"
    echo ">>> Title ID (explicit): $FINAL_TITLE_ID"
else
    EXE_FILES="$(find "$PROJECT_ROOT" -maxdepth 2 -name "*.exe" 2>/dev/null | sort)"
    if [ -n "$EXE_FILES" ]; then
        echo ">>> Hashing .exe file(s) for Title ID:"
        echo "$EXE_FILES" | sed 's/^/    /'
        EXE_HASH="$(sha256sum $EXE_FILES | sha256sum | awk '{print $1}')"
        HEX8="$(echo "$EXE_HASH" | cut -c1-8 | tr '[:lower:]' '[:upper:]')"
        FINAL_TITLE_ID="0100${HEX8}0000"
        echo ">>> Title ID (derived from .exe hash): $FINAL_TITLE_ID"
    else
        echo ">>> No .exe files found; generating random Title ID..."
        HEX8="$(head -c 16 /dev/urandom 2>/dev/null | md5sum | cut -c1-8 | tr '[:lower:]' '[:upper:]')"
        FINAL_TITLE_ID="0100${HEX8}0000"
        echo ">>> Title ID (random fallback): $FINAL_TITLE_ID"
    fi
fi

# ─── Resolve Icon Path ────────────────────────────────────────────────────────
ICON_PATH=""
if [ -n "$ICON_INPUT" ] && [ -f "$ICON_INPUT" ]; then
    ICON_PATH="$ICON_INPUT"
    echo ">>> Using user-specified icon: $ICON_PATH"
else
    # Try extracting icon from .exe file using wrestool / icotool
    EXE_FILE="$(find "$PROJECT_ROOT" -maxdepth 2 -name "*.exe" 2>/dev/null | head -1)"
    if [ -n "$EXE_FILE" ] && command -v wrestool &>/dev/null && command -v icotool &>/dev/null; then
        echo ">>> Attempting to extract icon from '$EXE_FILE'..."
        TMP_ICO="/tmp/exe_icon_$$.ico"
        wrestool -x -t 14 "$EXE_FILE" > "$TMP_ICO" 2>/dev/null || true
        if [ -s "$TMP_ICO" ]; then
            icotool -x -o "/tmp/extracted_icon_$$" "$TMP_ICO" 2>/dev/null || true
            BEST_PNG="$(ls /tmp/extracted_icon_$$*.png 2>/dev/null | tail -1 || true)"
            if [ -n "$BEST_PNG" ] && [ -f "$BEST_PNG" ]; then
                ICON_PATH="$BEST_PNG"
                echo ">>> Extracted icon from .exe: $ICON_PATH"
            fi
        fi
        rm -f "$TMP_ICO"
    fi

    # Fallback to game directory icons
    if [ -z "$ICON_PATH" ]; then
        if [ -f "$GAME_DIR/icon.png" ]; then
            ICON_PATH="$GAME_DIR/icon.png"
            echo ">>> Using game icon: $ICON_PATH"
        elif [ -f "$GAME_DIR/icon.jpg" ]; then
            ICON_PATH="$GAME_DIR/icon.jpg"
            echo ">>> Using game icon: $ICON_PATH"
        elif [ -f "$GAME_DIR/presplash.png" ]; then
            ICON_PATH="$GAME_DIR/presplash.png"
            echo ">>> Using presplash icon: $ICON_PATH"
        elif [ -f "$DEVKITPRO/libnx/default_icon.jpg" ]; then
            ICON_PATH="$DEVKITPRO/libnx/default_icon.jpg"
            echo ">>> Using libnx default icon: $ICON_PATH"
        fi
    fi
fi

# ─── Staging & Manual NSP Build ───────────────────────────────────────────────
STAGE_DIR="/tmp/renpy_nsp_stage_$$"
ROMFS_STAGE="$STAGE_DIR/romfs_raw"
PFS0_STAGE="$STAGE_DIR/pfs0_raw"

mkdir -p "$ROMFS_STAGE"
mkdir -p "$PFS0_STAGE"
trap 'rm -rf "$STAGE_DIR" /tmp/extracted_icon_$$*.png' EXIT

echo ">>> Staging RomFS files..."
cp -r "$RAW_ROMFS/." "$ROMFS_STAGE/"
mkdir -p "$ROMFS_STAGE/Contents/game"
cp -r "$GAME_DIR/." "$ROMFS_STAGE/Contents/game/"

echo ">>> Building romfs.bin via build_romfs..."
"$BUILD_ROMFS" "$ROMFS_STAGE" "$PFS0_STAGE/romfs.bin"

echo ">>> Creating control.nacp via nacptool (TitleID: $FINAL_TITLE_ID, Name: '$TITLE_NAME', Publisher: '$PUBLISHER', Version: '$VERSION')..."
"$NACPTOOL" --create "$TITLE_NAME" "$PUBLISHER" "$VERSION" "$PFS0_STAGE/control.nacp" --titleid="$FINAL_TITLE_ID"

echo ">>> Staging ExeFS main binary..."
cp "$RAW_MAIN" "$PFS0_STAGE/main"

if [ -n "$ICON_PATH" ] && [ -f "$ICON_PATH" ]; then
    echo ">>> Staging control icon..."
    cp "$ICON_PATH" "$PFS0_STAGE/icon_AmericanEnglish.dat"
fi

echo ">>> Building NSP container via build_pfs0..."
"$BUILD_PFS0" "$PFS0_STAGE" "./$OUTPUT_NSP"

if [ -f "./$OUTPUT_NSP" ]; then
    echo "=========================================================================="
    echo " SUCCESS: Created $OUTPUT_NSP"
    echo " Title ID : $FINAL_TITLE_ID"
    echo " Title    : $TITLE_NAME"
    echo " Publisher: $PUBLISHER"
    echo " Version  : $VERSION"
    echo " Built natively using devkitPro switch-dev tools (build_romfs + nacptool + build_pfs0)."
    echo "=========================================================================="
else
    echo "ERROR: NSP generation failed."
    exit 1
fi
