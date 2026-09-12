#!/usr/bin/env bash
set -e

# Resolve repository root even if invoked via symlink
TARGET="${BASH_SOURCE[0]}"
while [ -h "$TARGET" ]; do
  DIR="$(cd -P "$(dirname "$TARGET")" >/dev/null 2>&1 && pwd)"
  TARGET="$(readlink "$TARGET")"
  [[ $TARGET != /* ]] && TARGET="$DIR/$TARGET"
done
REPO_ROOT="$(cd -P "$(dirname "$TARGET")" >/dev/null 2>&1 && pwd)"

VERSION="0.2.0"

# Print banner and help message
showHelp() {
  cat << 'EOF'
InkDroid CLI - Transforming Android into a minimal E-Reader

Usage:
  ink [OPTIONS] <COMMAND> [COMMAND_OPTIONS]

Commands:
  install, setup       Run full installation and debloat pipeline
  uninstall, restore   Restore debloated packages and default settings
  book, fetch          Search and download e-books (fetchbook)
  push, send           Push downloaded e-book files to connected tablet
  status, info         Display detailed diagnostic information of target device
  display, screen      Configure e-ink screen settings (grayscale, blue filter, reset)
  help                 Show this help screen

Global Options:
  -s, --serial SERIAL  Target specific ADB device serial
  -v, --version        Show version information
  -h, --help           Show this help screen

Examples:
  ink status
  ink install --only-debloat
  ink uninstall --only-packages
  ink book "Dom Casmurro" -f epub -l pt
  ink push ~/Books/Dom_Casmurro.epub
  ink display monochrome
EOF
  exit 0
}

# Verify device connectivity
requireDevice() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "Error: adb command not found. Please install android-tools." >&2
    exit 1
  fi

  local count
  count=$(adb devices | grep -v "List of devices attached" | grep -c "device$" || true)

  if [ "$count" -eq 0 ]; then
    echo "Error: No compatible Android device found." >&2
    echo "Make sure USB debugging is enabled and authorized on your device." >&2
    exit 1
  elif [ "$count" -gt 1 ] && [ -z "$ANDROID_SERIAL" ]; then
    echo "Error: Multiple devices connected. Specify one using -s or --serial <SERIAL>:" >&2
    adb devices | grep -v "List of devices attached" | grep "device$" | awk '{print "  " $1}' >&2
    exit 1
  fi
}

# Subcommand: status
cmdStatus() {
  requireDevice

  local vendor model android_ver patch abi battery width_height density launcher daltonizer
  vendor=$(adb shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')
  model=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
  android_ver=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
  patch=$(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')
  abi=$(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
  battery=$(adb shell dumpsys battery 2>/dev/null | grep -i "level:" | awk '{print $2}' | tr -d '\r')
  width_height=$(adb shell wm size 2>/dev/null | tr -d '\r' | sed 's/Physical size: //')
  density=$(adb shell wm density 2>/dev/null | tr -d '\r' | sed 's/Physical density: //')
  launcher=$(adb shell cmd role get-role-holders android.app.role.HOME 2>/dev/null | tr -d '\r')
  daltonizer=$(adb shell settings get secure accessibility_display_daltonizer_enabled 2>/dev/null | tr -d '\r')

  echo -e "\e[32m=== InkDroid Device Diagnostics ===\e[0m"
  echo "Manufacturer:   ${vendor:-Unknown}"
  echo "Model:          ${model:-Unknown}"
  echo "Android:        ${android_ver:-Unknown} (Security patch: ${patch:-N/A})"
  echo "CPU ABI:        ${abi:-Unknown}"
  echo "Battery:        ${battery:-Unknown}%"
  echo "Resolution:     ${width_height:-Unknown}"
  echo "DPI Density:    ${density:-Unknown}"
  echo "Default HOME:   ${launcher:-Default}"
  echo "Grayscale Mode: $([ "$daltonizer" = "1" ] && echo "Active" || echo "Inactive")"
  echo "-----------------------------------"
}

# Subcommand: push e-books to device
cmdPush() {
  requireDevice

  if [ $# -eq 0 ]; then
    echo "Usage: ink push <file1> [file2...]" >&2
    exit 1
  fi

  echo "Ensuring /sdcard/Books directory exists on device..."
  adb shell mkdir -p /sdcard/Books >/dev/null 2>&1

  for file in "$@"; do
    if [ ! -f "$file" ]; then
      echo "Warning: File not found: $file" >&2
      continue
    fi

    echo "Pushing $(basename "$file") to /sdcard/Books/..."
    adb push "$file" /sdcard/Books/

    # Notify Android media scanner
    local remote_path="/sdcard/Books/$(basename "$file")"
    adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://${remote_path}" >/dev/null 2>&1 || true
    echo -e "\e[32m[DONE]\e[0m Transferred $(basename "$file")"
  done
}

# Subcommand: display configuration
cmdDisplay() {
  requireDevice

  local profile="${1:-}"

  case "$profile" in
    0|mono|monochrome)
      echo "Applying monochromatic e-ink profile..."
      adb shell settings put global window_animation_scale 0
      adb shell settings put global transition_animation_scale 0
      adb shell settings put global animator_duration_scale 0
      adb shell settings put secure accessibility_display_daltonizer_enabled 1
      adb shell settings put secure accessibility_display_daltonizer 0
      adb shell settings put secure acessibility_display_daltonizer_enable 1 >/dev/null 2>&1 || true
      adb shell settings put secure acessibility_display_daltonizer 0 >/dev/null 2>&1 || true
      echo -e "\e[32m[DONE]\e[0m Monochromatic mode enabled"
      ;;
    1|blue|bluelight)
      echo "Applying blue light filter profile..."
      adb shell settings put secure night_display_activated 1
      adb shell settings put secure night_display_color_temperature 3000
      echo -e "\e[32m[DONE]\e[0m Blue light filter enabled"
      ;;
    reset|normal|default)
      echo "Restoring default display and animation settings..."
      adb shell settings put global window_animation_scale 1
      adb shell settings put global transition_animation_scale 1
      adb shell settings put global animator_duration_scale 1
      adb shell settings put secure accessibility_display_daltonizer_enabled 0
      adb shell settings put secure accessibility_display_daltonizer -1
      adb shell settings put secure acessibility_display_daltonizer_enable 0 >/dev/null 2>&1 || true
      adb shell settings put secure acessibility_display_daltonizer 0 >/dev/null 2>&1 || true
      adb shell settings put secure night_display_activated 0
      echo -e "\e[32m[DONE]\e[0m Display settings reset to defaults"
      ;;
    *)
      echo "Select display mode:"
      echo "  [0] Monochromatic display (E-Ink simulation)"
      echo "  [1] Blue light filter only"
      echo "  [2] Reset to defaults (normal animations and color)"
      read -r -p "Enter choice [0-2]: " choice
      case "$choice" in
        0|"") cmdDisplay monochrome ;;
        1) cmdDisplay blue ;;
        2) cmdDisplay reset ;;
        *) echo "Invalid choice." ;;
      esac
      ;;
  esac
}

# Parse global options first
while [ $# -gt 0 ]; do
  case "$1" in
    -s|--serial)
      export ANDROID_SERIAL="$2"
      shift 2
      ;;
    -v|--version)
      echo "InkDroid CLI v${VERSION}"
      exit 0
      ;;
    -h|--help)
      showHelp
      ;;
    --)
      shift
      break
      ;;
    -*)
      # If unknown global option before command, show help
      echo "Unknown option: $1" >&2
      showHelp
      ;;
    *)
      # First non-option argument is the subcommand
      break
      ;;
  esac
done

if [ $# -eq 0 ]; then
  showHelp
fi

COMMAND="$1"
shift

case "$COMMAND" in
  install|setup)
    exec "${REPO_ROOT}/scripts/InkDroid_install.sh" "$@"
    ;;
  uninstall|restore)
    exec "${REPO_ROOT}/scripts/InkDroid_uninstall.sh" "$@"
    ;;
  book|fetch|fetchbook)
    exec "${REPO_ROOT}/scripts/fetchbook" "$@"
    ;;
  push|send)
    cmdPush "$@"
    ;;
  status|info)
    cmdStatus "$@"
    ;;
  display|screen)
    cmdDisplay "$@"
    ;;
  help)
    showHelp
    ;;
  *)
    echo "Error: Unknown command '$COMMAND'" >&2
    echo "Run 'ink --help' for available commands." >&2
    exit 1
    ;;
esac
