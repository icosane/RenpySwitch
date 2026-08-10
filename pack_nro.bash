#!/usr/bin/env bash
set -e

# ─── Environment Setup ────────────────────────────────────────────────────────
source /etc/profile.d/devkit-env.sh 2>/dev/null || true
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export PATH="${DEVKITPRO}/tools/bin:$PATH"

# ─── Usage Help ───────────────────────────────────────────────────────────────
show_help() {
    cat << EOF
RenPySwitch NRO Package Generator

Usage:
  ./pack_nro.bash <game_directory> <output.nro> <title_name> [options]

Required Positional Arguments:
  1. <game_directory>  Path to the Ren'Py game project folder (containing 'game/').
  2. <output.nro>      Output NRO filename/path (e.g. MyGame.nro).
  3. <title_name>      Game title name shown in Homebrew Launcher (e.g. "My Game").

Options:
  -p, --publisher, --developer NAME
                       Publisher/Developer name (default: "RenPy Switch").
  -v, --version VER    Game version string (default: "1.0.0").
  --icon PATH          Path to custom 256x256 PNG/JPG icon (default: .exe icon -> game icon -> libnx default icon).
  -h, --help           Show this help message.

Examples:
  ./pack_nro.bash /path/to/MyGame MyGame.nro "My Game Title"
  ./pack_nro.bash /path/to/MyGame MyGame.nro "My Game Title" --publisher "My Studio" --version "1.2.0"
  ./pack_nro.bash /path/to/MyGame MyGame.nro "Super Game" --icon my_icon.png
EOF
}

# ─── Flag Parsing ─────────────────────────────────────────────────────────────
GAME_INPUT=""
OUTPUT_NRO=""
TITLE_NAME=""
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
            OUTPUT_NRO="$2"
            shift 2
            ;;
        -n|--name|--title-name)
            TITLE_NAME="$2"
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
if [ -z "$OUTPUT_NRO" ] && [ ${#POSITIONAL[@]} -gt 1 ]; then
    OUTPUT_NRO="${POSITIONAL[1]}"
fi
if [ -z "$TITLE_NAME" ] && [ ${#POSITIONAL[@]} -gt 2 ]; then
    TITLE_NAME="${POSITIONAL[2]}"
fi

if [ -z "$GAME_INPUT" ] || [ -z "$OUTPUT_NRO" ] || [ -z "$TITLE_NAME" ]; then
    echo "ERROR: Missing required positional arguments."
    show_help
    exit 1
fi

ELF2NRO="$(which elf2nro || true)"
if [ -z "$ELF2NRO" ]; then
    echo "ERROR: 'elf2nro' not found in PATH or /opt/devkitpro/tools/bin."
    echo "       Please make sure devkitPro / switch-tools are installed."
    exit 1
fi

NACPTOOL="$(which nacptool || true)"
if [ -z "$NACPTOOL" ]; then
    echo "ERROR: 'nacptool' not found in PATH or /opt/devkitpro/tools/bin."
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

case "$OUTPUT_NRO" in
    *.nro) ;;
    *) OUTPUT_NRO="${OUTPUT_NRO}.nro" ;;
esac

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

# ─── Staging & Assembly ───────────────────────────────────────────────────────
STAGE_DIR="/tmp/renpy_nro_stage_$$"
mkdir -p "$STAGE_DIR"
trap 'rm -rf "$STAGE_DIR" /tmp/extracted_icon_$$*.png' EXIT

echo ">>> Staging Switch romfs..."
cp -r "$RAW_ROMFS" "$STAGE_DIR/romfs"

echo ">>> Copying game files from '$GAME_DIR'..."
mkdir -p "$STAGE_DIR/romfs/Contents/game"
cp -r "$GAME_DIR/." "$STAGE_DIR/romfs/Contents/game/"

echo ">>> Creating control.nacp (Name: '$TITLE_NAME', Publisher: '$PUBLISHER', Version: '$VERSION')..."
"$NACPTOOL" --create "$TITLE_NAME" "$PUBLISHER" "$VERSION" "$STAGE_DIR/control.nacp"

echo ">>> Packaging into $OUTPUT_NRO..."
ELF2NRO_ARGS=("$RAW_MAIN" "$OUTPUT_NRO" "--romfsdir=$STAGE_DIR/romfs" "--nacp=$STAGE_DIR/control.nacp")

if [ -n "$ICON_PATH" ] && [ -f "$ICON_PATH" ]; then
    ELF2NRO_ARGS+=("--icon=$ICON_PATH")
fi

"$ELF2NRO" "${ELF2NRO_ARGS[@]}"

echo "=========================================================================="
echo " SUCCESS: Created $OUTPUT_NRO"
echo " Title    : $TITLE_NAME"
echo " Publisher: $PUBLISHER"
echo " Version  : $VERSION"
echo " Put $OUTPUT_NRO into the '/switch/' folder on your SD card."
echo "=========================================================================="
