# InkDroid 📖

> **Turn legacy Android tablets into minimal, distraction-free E-Readers.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android%207%2B-brightgreen.svg)](https://www.android.com/)
[![CLI: ink](https://img.shields.io/badge/CLI-ink-purple.svg)](ink)
[![Research: TCC](https://img.shields.io/badge/Academic-Paper%20%28PT--BR%29-orange.svg)](#-academic-documentation--scientific-paper)

**InkDroid** is an open-source toolchain designed for **hardware repurposing** (*Green IT*). It revitalizes older, resource-constrained Android devices (such as budget and public-school tablets like the Multilaser M8 4G) by transforming them into dedicated, paper-like digital reading devices.

Through non-invasive **Android Debug Bridge (ADB)** automation, InkDroid strips away battery-draining telemetry and social distractions, emulates monochrome e-ink visuals at the framework level, and deploys a distraction-free reading environment — all **without requiring root privileges**.

---

## 📑 Table of Contents

- [Why InkDroid?](#-why-inkdroid)
- [Key Features](#-key-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Unified CLI Reference (`ink`)](#-unified-cli-reference-ink)
  - [Diagnostics (`ink status`)](#1-diagnostics-ink-status)
  - [Transforming the Tablet (`ink install`)](#2-transforming-the-tablet-ink-install)
  - [Restoring the Device (`ink uninstall`)](#3-restoring-the-device-ink-uninstall)
  - [Searching & Downloading Books (`ink book`)](#4-searching--downloading-books-ink-book)
  - [Transferring Books (`ink push`)](#5-transferring-books-ink-push)
  - [Toggling Screen Profiles (`ink display`)](#6-toggling-screen-profiles-ink-display)
- [Academic Documentation & Scientific Paper](#-academic-documentation--scientific-paper)
  - [Compiling the LaTeX Paper](#compiling-the-latex-paper)
- [Project Architecture](#-project-architecture)
- [Safety & Reversibility](#-safety--reversibility)
- [License](#-license)

---

## 💡 Why InkDroid?

Modern mobile operating systems suffer from **Software Aging** (Parnas, 1994): continuous system updates and background telemetry demand computing power far beyond what older hardware was built for. As a result, millions of functionally intact tablets end up abandoned in drawers or landfills as electronic waste.

InkDroid solves this by converting general-purpose devices into **single-purpose tools for deep work and reading** (Cal Newport, 2019):
- **Combats E-Waste:** Extends device lifespan instead of buying expensive specialized e-readers (e.g., Kindle, Kobo).
- **Reduces Cognitive Fatigue:** Eliminates notification hooks, bright saturated interfaces, and background interruptions.
- **Eye-Friendly Reading:** Emulates e-ink paper contrast via native monochrome rendering and locked refresh rates to mitigate **Computer Vision Syndrome (CVS)**.

---

## ✨ Key Features

- **Zero-Root ADB Automation:** Safe, non-destructive modifications performed through official Android developer protocols.
- **Smart Debloater:** Selectively disables vendor bloatware, background trackers, and Google Mobile Services (GMS) for user 0, recovering RAM and drastically cutting battery drain.
- **E-Ink Display Simulation:** Activates system-wide grayscale (Daltonizer), turns off UI animations, and restricts display refresh rates to maximize battery autonomy.
- **Pre-configured Reading Environment:** Automatically provisions **[KOReader](https://koreader.rocks/)** (a premier open-source document viewer) and **[Olauncher](https://github.com/tanujnotes/Olauncher)** (a minimalist, text-only home screen).
- **Built-in Book Engine (`fetchbook`):** Search and download public-domain and open-access books (Project Gutenberg, Internet Archive, LibGen) directly from the terminal.
- **Instant ADB Sync:** Push `.epub`, `.pdf`, or `.mobi` books straight to `/sdcard/Books/` on the tablet with automatic Android media indexing.
- **100% Reversible:** Restore all default packages, animations, and original launchers at any time with a single command.

---

## 📋 Prerequisites

### 1. Hardware
- An Android tablet or phone (tested on Android 11; compatible with Android 7+).
- A reliable USB data cable.
- A host computer running **Linux**, **macOS**, or **Windows with WSL**.

### 2. Software
InkDroid automatically checks and installs dependencies on supported Linux distributions (`apt`, `dnf`, `pacman`, `zypper`). You will need:
- `adb` (Android platform-tools)
- `curl`
- `python3` (built-in fallback parser, no `jq` required)
- `fzf` *(optional, for interactive menu navigation)*

### 3. Enable USB Debugging on your Tablet (For Beginners)
1. Open **Settings** on your Android device.
2. Navigate to **About tablet** (or **About phone**).
3. Tap **Build number** **7 times** until you see the message *"You are now a developer!"*.
4. Go back to **System** > **Developer options**.
5. Enable **USB debugging**.
6. Connect the tablet to your computer via USB.
7. On the tablet screen, check **"Always allow from this computer"** and tap **Allow**.

---

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Bagi-sh/InkDroid.git
   cd InkDroid
   ```

2. **Verify your device connection:**
   ```bash
   ./ink status
   ```

3. **Run the transformation:**
   ```bash
   ./ink install
   ```

Follow the on-screen prompts to debloat, install reading apps, set the minimalist launcher, and apply the monochrome e-ink profile!

---

## 🛠️ Unified CLI Reference (`ink`)

InkDroid features a single orchestrator CLI (`ink`) located at the root of the project. You can run it directly with `./ink` or symlink it to your `PATH` (e.g., `ln -s $(pwd)/ink ~/.local/bin/ink`).

```
Usage:
  ink [GLOBAL_OPTIONS] <COMMAND> [COMMAND_OPTIONS]
```

### 1. Diagnostics (`ink status`)
Inspects the connected tablet and displays a clean health report:
```bash
./ink status
```
*Output includes: Manufacturer, Model, Android release, Security patch, CPU ABI, Battery level, Resolution, Screen density (DPI), Current default launcher, and Grayscale mode status.*

---

### 2. Transforming the Tablet (`ink install`)
Runs the debloat, app deployment, and e-ink display configuration:
```bash
# Standard interactive setup
./ink install

# Non-interactive mode (auto-accepts defaults)
./ink install -y

# Run only specific stages:
./ink install --only-debloat     # Debloat packages only
./ink install --only-apps        # Download and install KOReader & Olauncher only
./ink install --only-display     # Apply e-ink grayscale & animations only
./ink install --only-launcher    # Set Olauncher as default HOME only

# Skip specific stages:
./ink install --skip-apps        # Debloat and configure screen, but don't install apps
./ink install --skip-debloat     # Keep existing apps, just set up screen & reading apps
```

---

### 3. Restoring the Device (`ink uninstall`)
Reverts all changes safely, restoring the tablet to its original factory state:
```bash
# Full restoration (re-enables system packages, resets display, removes KOReader/Olauncher)
./ink uninstall

# Non-interactive restoration
./ink uninstall -y

# Granular recovery:
./ink uninstall --only-packages  # Re-enable debloated apps only
./ink uninstall --only-display   # Restore default colors and animations only
./ink uninstall --only-apps      # Remove KOReader and Olauncher only
```

---

### 4. Searching & Downloading Books (`ink book`)
Finds and downloads e-books using a resilient multi-tier engine (Project Gutenberg REST API, Internet Archive, and LibGen mirrors):
```bash
# Search for a title in Portuguese (default format: EPUB)
./ink book "Dom Casmurro"

# Search by author with language and format filters
./ink book "Machado de Assis" -l pt -f epub

# Search across public-domain Gutenberg classics only
./ink book "The Time Machine" -s gutenberg -l en -f epub

# Auto-download first result and transfer immediately to tablet
./ink book -a -p "Memorias Posthumas"
```

| Flag | Description | Default |
| :--- | :--- | :--- |
| `-f, --format` | Format (`epub`, `pdf`, `mobi`) | `epub` |
| `-l, --lang` | Language code (`pt`, `en`, `es`, `all`) | `pt` |
| `-s, --source` | Source (`gutenberg`, `archive`, `libgen`, `all`) | `all` |
| `-d, --dir` | Local download folder | `.` |
| `-a, --auto` | Automatically pick the first result | `false` |
| `-p, --push` | Automatically push the downloaded file to the tablet | `false` |

---

### 5. Transferring Books (`ink push`)
Sends local e-book files directly to the tablet's `/sdcard/Books/` directory and broadcasts a media scanner trigger so KOReader detects them immediately:
```bash
# Push a single book
./ink push ~/Downloads/dune.epub

# Push multiple books at once
./ink push books/*.epub
```

---

### 6. Toggling Screen Profiles (`ink display`)
Switch display color and animation profiles on the fly:
```bash
# Activate monochrome e-ink mode (grayscale + animations off)
./ink display monochrome

# Activate warm blue light filter (night reading)
./ink display blue

# Reset screen to standard Android defaults (color + normal animations)
./ink display reset
```

---

## 🎓 Academic Documentation & Scientific Paper

InkDroid originated as a formal Graduation Thesis (*Trabalho de Conclusão de Curso - TCC*) in Technical Computer Science at **Colégio Estadual de Aplicação de Tempo Integral Anísio Teixeira (CEAAT)** in Salvador, Bahia, Brazil.

> [!NOTE]
> **Language Notice:** The scientific paper and associated theoretical documentation are written in **Portuguese (PT-BR)**, as required by Brazilian academic standards (ABNT).

### Theoretical Framework
The thesis addresses:
1. **Application Layer:** Reversing *Software Aging* (Parnas, 1994) via radical debloating; eliminating Google Mobile Services (GMS) background processes to cut battery drain by ~11.76% (Monteiro et al., 2023).
2. **Framework Layer:** Mitigating *Computer Vision Syndrome (CVS)* via grayscale simulation (`settings.db`), blue light filtering, and animation suppression (Benedetto et al., 2013; Sá, 2016).
3. **Kernel Layer:** Down-throttling refresh rates via *SurfaceFlinger* and applying CPU underclocking guided by *Composite Desirability* models (Pontes, 2017).

### Document Files
- Source LaTeX file: [`documentation/main.tex`](documentation/main.tex)
- BibTeX References: [`documentation/referencias.bib`](documentation/referencias.bib)
- Pre-compiled PDF: [`documentation/build/main.pdf`](documentation/build/main.pdf)

---

### Compiling the LaTeX Paper

The thesis uses the Brazilian National Standards format via the **abnTeX2** package suite.

#### Option A: Using `latexmk` (Recommended)
Make sure you have TeX Live installed (`texlive-full` on Debian/Ubuntu or `texlive-publishers`):

```bash
# On Ubuntu / Debian:
sudo apt-get install texlive-full latexmk

# On Arch Linux:
sudo pacman -S texlive-meta

# Compile to PDF:
cd documentation
latexmk -pdf -output-directory=build main.tex
```
The resulting PDF will be saved to `documentation/build/main.pdf`.

#### Option B: Manual Multi-Pass Compilation (`pdflatex` + `bibtex`)
If you prefer standard CLI tools without `latexmk`:

```bash
cd documentation
mkdir -p build

# 1. First pass (generates auxiliary files)
pdflatex -output-directory=build main.tex

# 2. Compile bibliography (BibTeX)
bibtex build/main

# 3. Two additional passes to resolve cross-references and citations
pdflatex -output-directory=build main.tex
pdflatex -output-directory=build main.tex
```

---

## 📂 Project Architecture

```
InkDroid/
├── ink                             # Main CLI orchestrator (entrypoint)
├── scripts/
│   ├── InkDroid_install.sh         # Function-oriented debloater & installer
│   ├── InkDroid_uninstall.sh       # Function-oriented factory restoration tool
│   └── fetchbook                   # Multi-tier e-book downloader & sync tool
├── dependences/
│   └── blacklist.json              # Cataloged packages (Google, Bloatware, Social)
├── documentation/                  # Academic paper & research (LaTeX / ABNT)
│   ├── main.tex                    # Thesis source code (PT-BR)
│   ├── referencias.bib             # Academic citations and bibliography
│   └── build/main.pdf              # Compiled thesis document (PDF)
└── README.md                       # Documentation & user guide
```

---

## 🛡️ Safety & Reversibility

- **No Root Required:** InkDroid uses standard user-space ADB permissions (`--user 0`). It does not modify system partitions, meaning it **cannot brick your device**.
- **Instant Recovery:** Running `./ink uninstall` re-enables all system packages and resets animations.
- **Audit Logs:** Every package removal and installation action is logged to `debloatlog.txt` and `restorelog.txt` for total transparency.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

```text
MIT License - Copyright (c) 2026 bagi-sh
```

*If you are building an Android ROM or a broader open-source hardware initiative inspired by this work, the author warmly invites you to use the **InkDroid** name.* 🚀
