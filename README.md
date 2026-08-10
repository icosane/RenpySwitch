# RenpySwitch

Build pipeline for **Ren'Py on Nintendo Switch**, powered by GitHub Actions and [NXPython](https://github.com/jvrcruzGAMES/NXPython).

## What it does

1. Downloads Ren'Py 8.3.4 sources and SDL2 bindings
2. Applies Switch-specific patches to Ren'Py
3. Compiles Ren'Py modules with Cython
4. Packages the runtime into `lib.zip`
5. Cross-compiles the Switch executable (`.nso`)
6. Assembles a ready-to-use blank Switch project under `raw/`

---

## Images and packages used

| Dependency | Version |
|---|---|
| Ubuntu | 24.04 |
| devkitpro/devkita64 | 20230910 |
| Ren'Py SDK | 8.3.4 |
| Python | 3.14 (via [NXPython](https://github.com/jvrcruzGAMES/NXPython)) |
| Cython | 3.0.10 |
| setuptools | latest |

---

## Local Build

The build requires a **Linux environment**. On Windows, use **WSL2** or **Docker**.

### Option 1 — Docker (Recommended, mirrors CI exactly)

```bash
# Pull the exact image used in GitHub Actions
docker pull devkitpro/devkita64:20230910

# Run a container with the repo mounted
docker run -it --rm \
  -v /path/to/RenpySwitch:/workspace \
  devkitpro/devkita64:20230910 bash

# Inside the container:
cd /workspace
sed -i 's/\r//' setup.bash build.bash link_sources.bash
bash setup.bash
bash build.bash
```

Output will be in `./raw/`.

---

### Option 2 — WSL2 (Ubuntu 24.04)

#### 1. Install WSL2 with Ubuntu 24.04

```powershell
wsl --install -d Ubuntu-24.04
```

#### 2. Install devkitPro inside WSL

The `apt.devkitpro.org` install script may return 403. Use the manual `.deb` install instead:

```bash
# Download devkitpro-pacman from GitHub releases
wget https://github.com/devkitPro/pacman/releases/download/v1.0.2/devkitpro-pacman.amd64.deb
sudo dpkg -i devkitpro-pacman.amd64.deb
sudo apt-get install -f

# Update and install Switch toolchain
sudo dkp-pacman -Sy
sudo dkp-pacman -S switch-dev --noconfirm

# Load environment
source /etc/profile.d/devkit-env.sh
export DEVKITPRO=/opt/devkitpro
```

#### 3. Fix line endings and run the scripts

The scripts use Unix line endings. If you edited them on Windows, fix them first:

```bash
cd /mnt/c/Users/<your-user>/Downloads/RenpySwitch

# Fix CRLF (always safe to run)
sed -i 's/\r//' setup.bash build.bash link_sources.bash

# Install dependencies, create venv, and setup cached sources
sudo bash setup.bash

# Re-extract and re-patch sources (optional):
sudo bash setup.bash --force

# Compile everything (~10–20 min)
sudo bash build.bash
```

> **Download Caching**: `setup.bash` automatically caches all downloaded archives (Ren'Py SDK, source tarballs, devkitPro portlib packages) inside `./downloads/`. Subsequent runs of `setup.bash` skip downloading and compiling existing assets. Passing `--force` re-extracts and re-patches source directories.

> **Virtual environment**: `setup.bash` automatically creates a `.venv/` in the repo root and installs all Python packages (Cython, setuptools, etc.) into it. This avoids the Ubuntu 24.04 PEP 668 error _"externally managed environment"_. `build.bash` activates the same `.venv` automatically — you do not need to activate it manually.

To inspect or use the venv manually:

```bash
source .venv/bin/activate
python --version  # should show 3.x
pip list
```

---

### Output

After `build.bash` completes successfully, the `./raw/` directory contains:

```
raw/
├── switch/
│   ├── exefs/
│   │   └── main          ← Switch NSO executable
│   └── romfs/
│       └── Contents/
│           ├── renpy.py
│           ├── lib.zip   ← Python 3.14 + Ren'Py runtime
│           └── renpy/
│               └── common/
└── renpy_clear/          ← Blank Ren'Py project template
```

---

## Packaging Games (`.nro` or `.nsp`)

Two automated helper scripts are provided to convert any Ren'Py game folder into a Switch format. Both scripts share a unified CLI interface requiring **3 positional arguments**:

```text
bash pack_<format>.bash <game_directory> <output_file> <title_name> [options]
```

---

### 1. Package as `.nro` (Homebrew Launcher)

Creates a standalone `.nro` file with embedded `control.nacp` metadata and icon.

```bash
# Basic positional usage:
bash pack_nro.bash /path/to/MyRenpyGame MyGame.nro "My Game Title"

# Flag-based options alongside positional arguments:
bash pack_nro.bash /path/to/MyRenpyGame MyGame.nro "My Game Title" -p "My Studio" -v "1.2.0"
```

---

### 2. Package as `.nsp` (Installable Title)

Creates an installable `.nsp` package natively using devkitPro's official `switch-dev` tools (`build_romfs` + `nacptool` + `build_pfs0`) without external third-party utilities:

```bash
# Basic positional usage (<game_directory> <output.nsp> <title_name>):
bash pack_nsp.bash /path/to/MyRenpyGame MyGame.nsp "My Game Title"

# Flag-based options alongside positional arguments:
bash pack_nsp.bash /path/to/MyRenpyGame MyGame.nsp "My Game Title" -p "My Studio" -v "1.2.0"
```

---

### CLI Reference

| Argument / Flag | Description | Default Value |
|---|---|---|
| `<game_directory>`, `-i` | Path to game folder *(positional arg 1)* | **Required** |
| `<output_file>`, `-o` | Output `.nro` / `.nsp` filename *(positional arg 2)* | **Required** |
| `<title_name>`, `-n` | Game title name on Switch home screen *(positional arg 3)* | **Required** |
| `-p`, `--publisher`, `--developer` | Publisher/Developer name | `"RenPy Switch"` |
| `-v`, `--version` | Game version string | `"1.0.0"` |
| `--icon` | Custom 256×256 PNG/JPG icon path | Extracted `.exe` icon $\rightarrow$ Game icon $\rightarrow$ libnx default icon |
| `-t`, `--title-id` *(NSP only)* | Switch Title ID (16 hex chars) | `auto` *(hash of `.exe` / random fallback)* |

> **Native `switch-dev` Pipeline**: `pack_nsp.bash` compiles the game's RomFS image via `build_romfs`, generates application metadata via `nacptool`, and packages the final NSP container via `build_pfs0`.
>
> **Icon Extraction**: Both scripts automatically extract the icon embedded inside your game's `.exe` binary using `wrestool`. If no `.exe` icon is found, it falls back to `icon.png` in your game folder, and finally to devkitPro's official `libnx` default icon (`/opt/devkitpro/libnx/default_icon.jpg`).
>
> **Title ID Generation (NSP)**: If no Title ID is specified, the script computes a SHA-256 hash of the game's `.exe` binary to derive a unique 16-character Title ID (`0100<8-HEX-DIGITS>0000`). If no `.exe` is found, a random Title ID is generated automatically.

---

## NXPython — Python 3.14 for Switch

This project uses [NXPython](https://github.com/jvrcruzGAMES/NXPython) as the cross-compiled CPython 3.14 base for the Nintendo Switch target.

`setup.bash` clones NXPython and builds it automatically using the devkitA64 toolchain. The result is a static `libpython3.14.a` installed into the devkitPro portlibs.

If you already have a pre-built NXPython portlib installed, you can skip the NXPython build step by commenting it out in `setup.bash`.

---

## Troubleshooting

| Error | Fix |
|---|---|
| `$'\r': command not found` | Run `sed -i 's/\r//' setup.bash build.bash link_sources.bash` |
| `externally-managed-environment` | `setup.bash` handles this via `.venv`; make sure you ran it first |
| `Package 'egl' not found` | Run `sudo apt-get install libegl-dev libgles-dev` |
| `python3: command not found` | Run `sudo apt-get install python3 python3-dev python3-pip python3-venv` |
| `dkp-pacman: command not found` | Install devkitPro (see step 2 above) |
| `403 Forbidden` on `apt.devkitpro.org` | Use the manual `.deb` install from GitHub releases |
| CMake `libpython3.14.a` not found | Build NXPython first, or check that portlibs are installed |
| `Venv not found` in build.bash | Run `setup.bash` before `build.bash` |
