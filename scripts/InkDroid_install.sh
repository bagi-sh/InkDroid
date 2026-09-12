#!/usr/bin/env bash
set -e

# Repository and environment variables
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES="android-tools curl bc jq"
LOG_ACTIONS="$REPO/debloatlog.txt"
JSON="$REPO/dependences/blacklist.json"

DO_DEPS=true
DO_DEBLOAT=true
DO_APPS=true
DO_LAUNCHER=true
DO_DISPLAY=true
AUTO_CONFIRM=false

# Install required host dependencies if missing
installDependencies() {
  if command -v adb >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    return 0
  fi

  echo "Installing required host dependencies: $PACKAGES..."
  if [ -x "$(command -v apt-get)" ]; then 
    sudo apt-get update && sudo apt-get install -y $PACKAGES
  elif [ -x "$(command -v dnf)" ]; then
    sudo dnf install -y $PACKAGES
  elif [ -x "$(command -v pacman)" ]; then
    sudo pacman -Sy --noconfirm $PACKAGES
  elif [ -x "$(command -v zypper)" ]; then
    sudo zypper install -y $PACKAGES
  else 
    echo "ERROR: couldn't install dependencies packages, please install $PACKAGES manually."
    exit 1 
  fi
}

# Verify and identify connected Android device
checkDevice() {
  local count
  count=$(adb devices | grep -v "List of devices attached" | grep -c "device$" || true)

  if [ "$count" -eq 1 ]; then
    echo "Status: Compatible device found."
    MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
    ANDROID_VER=$(adb shell getprop ro.build.version.release | tr -d '\r')
    VENDOR=$(adb shell getprop ro.product.manufacturer | tr -d '\r')

    echo -e "\e[32m[CONNECTED]\e[0m Device Detected without problems!"
    echo "--------------------------------------------------"
    echo " Vendor:    $VENDOR"
    echo " Model:     $MODEL"
    echo " Android:   $ANDROID_VER"
    echo "--------------------------------------------------"
  elif [ "$count" -gt 1 ]; then
    echo "Error: More than one device connected, please keep only one"
    exit 1
  else
    echo "Error: cannot find any compatible device."
    echo "Make sure debugging USB is on and with your PC checked as known"
    exit 1
  fi
}

# Prompt user confirmation before continuing
confirmDevice() {
  if [ "$AUTO_CONFIRM" = true ]; then
    return 0
  fi

  while true; do
    read -r -p "Continue script in the $MODEL? Y/n " yn
    case "$yn" in
      [Yy]* | "" ) break;;
      [Nn]* ) exit 0;;
      * ) break;;
    esac
  done
}

# Initialize report log
initLog() {
  if [ ! -f "$JSON" ]; then
    echo -e "\e[31m[ERROR]\e[0m JSON blacklist file not found in: $JSON"
    exit 1
  fi

  echo "=== SCRIPT REPORT ===" > "$LOG_ACTIONS"
  echo "DEVICE: $VENDOR $MODEL (Android $ANDROID_VER)" >> "$LOG_ACTIONS"
  echo "DATE: $(date)" >> "$LOG_ACTIONS"
  echo "---------------------------------" >> "$LOG_ACTIONS"
}

# Extract packages list from JSON using jq or python3 fallback
parseBlacklist() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.[] | .[]' "$JSON"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
with open('$JSON') as f:
    data = json.load(f)
for items in data.values():
    for pkg in items:
        print(pkg)
"
  else
    echo "Error: Neither jq nor python3 available to parse $JSON" >&2
    exit 1
  fi
}

# Uninstall bloatware packages for user 0
debloatPackages() {
  echo "starting search and debloat apps..."

  parseBlacklist | while read -r pacote; do
    [ -z "$pacote" ] && continue

    echo -n "Processing: $pacote ... "
    RESULT=$(adb shell pm uninstall -k --user 0 "$pacote" < /dev/null 2>&1 || true)

    if echo "$RESULT" | grep -q "Success"; then
      echo -e "\e[32m[REMOVED]\e[0m"
      echo "[SUCCESS] Uninstalled: $pacote" >> "$LOG_ACTIONS"
    elif echo "$RESULT" | grep -q "not installed"; then
      echo -e "\e[33m[PACKAGE NOT FOUND]\e[0m"
      echo "[INFO] Package not found: $pacote" >> "$LOG_ACTIONS"
    else
      echo -e "\e[31m[ERROR]\e[0m ($RESULT)"
      echo "[FAIL] Error on trying $pacote: $RESULT" >> "$LOG_ACTIONS"
    fi
  done

  echo "--------------------------------------------------"
  echo -e "\e[32m[FINISHED]\e[0m All of blacklist apps are uninstalled"
}

# Query latest release asset URL from GitHub
getReleaseApkUrl() {
  local repo_slug="$1"
  local keyword="${2:-}"
  local json
  json=$(curl -fsSL "https://api.github.com/repos/${repo_slug}/releases/latest" 2>/dev/null || true)
  [ -z "$json" ] && return 1

  if command -v jq >/dev/null 2>&1; then
    if [ -n "$keyword" ]; then
      echo "$json" | jq -r --arg kw "$keyword" '.assets[] | select(.name | endswith(".apk")) | select(.name | contains($kw)) | .browser_download_url' | head -n 1
    else
      echo "$json" | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url' | head -n 1
    fi
  elif command -v python3 >/dev/null 2>&1; then
    echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assets = data.get('assets', [])
kw = '$keyword'.lower()
urls = [a['browser_download_url'] for a in assets if a['name'].endswith('.apk')]
matched = [u for u in urls if kw in u.lower()] if kw else urls
print(matched[0] if matched else (urls[0] if urls else ''))
" 2>/dev/null
  fi
}

# Download and install KOReader
installKOReader() {
  echo "Downloading KOReader..."
  local url
  url=$(getReleaseApkUrl "koreader/koreader" "arm")
  [ -z "$url" ] && url=$(getReleaseApkUrl "koreader/koreader")

  if [ -n "$url" ]; then
    curl -fL "$url" -o /tmp/Koreader.apk
  fi

  if [ -s /tmp/Koreader.apk ]; then
    echo "[SUCCESS] Downloaded Koreader"
    echo "[SUCCESS] Downloaded Koreader" >> "$LOG_ACTIONS"
    echo "Installing..."
    RESULT=$(adb install -r --user 0 /tmp/Koreader.apk < /dev/null 2>&1 || true)
    if echo "$RESULT" | grep -q "Success"; then
      echo "[SUCCESS] Koreader Installed"
      echo "[SUCCESS] Koreader Installed" >> "$LOG_ACTIONS"
    else
      echo "[ERROR] Something went wrong on Koreader Installation" >> "$LOG_ACTIONS"
      echo "Error. Process will continue without Koreader"
    fi
  else
    echo "Warning: could not download KOReader, continuing..."
  fi
}

# Download and install Olauncher
installOlauncher() {
  echo "Downloading Olauncher..."
  local url
  url=$(getReleaseApkUrl "tanujnotes/Olauncher")

  if [ -n "$url" ]; then
    curl -fL "$url" -o /tmp/olauncher.apk
  fi

  if [ -s /tmp/olauncher.apk ]; then
    echo "[SUCCESS] Downloaded Olauncher"
    echo "[SUCCESS] Downloaded Olauncher" >> "$LOG_ACTIONS"
    echo "Installing..."
    RESULT=$(adb install -r --user 0 /tmp/olauncher.apk < /dev/null 2>&1 || true)
    if echo "$RESULT" | grep -q "Success"; then
      echo "[SUCCESS] Olauncher Installed"
      echo "[SUCCESS] Olauncher Installed" >> "$LOG_ACTIONS"
    else
      echo "[ERROR] Something went wrong on Olauncher Installation" >> "$LOG_ACTIONS"
      echo "Error. Process will continue without Olauncher"
    fi
  else
    echo "Warning: could not download Olauncher, continuing..."
  fi
}

# Set Olauncher as default system launcher
setDefaultLauncher() {
  if adb shell pm list packages | grep -q "app.olauncher"; then
    echo "Olauncher detected. Setting as default HOME..."
    adb shell cmd role add-role-holder android.app.role.HOME app.olauncher
    DEFAULTLAUNCHER=$(adb shell cmd role get-role-holders android.app.role.HOME | tr -d '\r')
    echo "The Default launcher is now $DEFAULTLAUNCHER"
    return 0
  else
    echo "Error: app.olauncher is not installed on the device." >&2
    return 1
  fi
}

# Prompt user to change default launcher
promptSetDefaultLauncher() {
  if [ "$AUTO_CONFIRM" = true ]; then
    setDefaultLauncher
    return 0
  fi

  while true; do
    read -r -p "Do you wish to change the default launcher? Y/n " yn
    case "$yn" in
      [Yy]* | "" ) setDefaultLauncher; break;;
      [Nn]* ) break;;
      * ) setDefaultLauncher; break;;
    esac
  done
}

# Apply e-ink ergonomic display configurations
configureDisplay() {
  local profile="${1:-0}"
  mapfile -t refreshlist < <(adb shell dumpsys display | grep -oE '(fps|refreshRate)=[0-9]+(\.[0-9]+)?' | sed 's/.*=//' | tr -d '\r' | LC_ALL=C sort -n -u)

  echo "turning off global animations..."
  adb shell settings put global window_animation_scale 0
  adb shell settings put global transition_animation_scale 0
  adb shell settings put global animator_duration_scale 0

  if [ ${#refreshlist[@]} -gt 0 ] && [ -n "${refreshlist[0]}" ]; then
    echo "limiting refresh rate to ${refreshlist[0]} Hz..."
    adb shell settings put system peak_refresh_rate "${refreshlist[0]}"
    adb shell settings put system min_refresh_rate "${refreshlist[0]}"
  fi

  if [ "$profile" -eq 1 ]; then
    echo "Activating global blue light filter..."
    adb shell settings put secure night_display_activated 1
    adb shell settings put secure night_display_color_temperature 3000
  else
    echo "Activating monochromatic display..."
    adb shell settings put secure accessibility_display_daltonizer_enabled 1
    adb shell settings put secure accessibility_display_daltonizer 0
    adb shell settings put secure acessibility_display_daltonizer_enable 1 >/dev/null 2>&1 || true
    adb shell settings put secure acessibility_display_daltonizer 0 >/dev/null 2>&1 || true
  fi
}

# Prompt user for display profile
promptConfigureDisplay() {
  if [ "$AUTO_CONFIRM" = true ]; then
    configureDisplay 0
    return 0
  fi

  echo "Which display color profile do you want? Default: 0"
  while true; do
    read -r -p "[0]: Monochromatic display; [1]: Global blue filter only: " choice
    case "$choice" in
      [0]* | "" ) configureDisplay 0; break;;
      [1]* ) configureDisplay 1; break;;
      * ) configureDisplay 0; break;;
    esac
  done
}

# Print command line help
showHelp() {
  cat << 'EOF'
Usage: InkDroid_install.sh [OPTIONS]

Options:
  --only-debloat    Run only package debloating
  --only-apps       Run only KOReader and Olauncher installation
  --only-launcher   Run only default launcher configuration
  --only-display    Run only e-ink display configuration
  --skip-deps       Skip installing host dependencies
  --skip-debloat    Skip debloating packages
  --skip-apps       Skip installing KOReader and Olauncher
  --skip-launcher   Skip setting default launcher
  --skip-display    Skip e-ink display configuration
  -y, --yes         Non-interactive mode (auto-confirm prompts)
  -h, --help        Show this help message
EOF
  exit 0
}

# Parse command line flags
parseArguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --only-debloat)
        DO_DEPS=false; DO_APPS=false; DO_LAUNCHER=false; DO_DISPLAY=false; DO_DEBLOAT=true; shift ;;
      --only-apps)
        DO_DEPS=false; DO_DEBLOAT=false; DO_LAUNCHER=false; DO_DISPLAY=false; DO_APPS=true; shift ;;
      --only-launcher)
        DO_DEPS=false; DO_DEBLOAT=false; DO_APPS=false; DO_DISPLAY=false; DO_LAUNCHER=true; shift ;;
      --only-display)
        DO_DEPS=false; DO_DEBLOAT=false; DO_APPS=false; DO_LAUNCHER=false; DO_DISPLAY=true; shift ;;
      --skip-deps)
        DO_DEPS=false; shift ;;
      --skip-debloat)
        DO_DEBLOAT=false; shift ;;
      --skip-apps)
        DO_APPS=false; shift ;;
      --skip-launcher)
        DO_LAUNCHER=false; shift ;;
      --skip-display)
        DO_DISPLAY=false; shift ;;
      -y|--yes)
        AUTO_CONFIRM=true; shift ;;
      -h|--help)
        showHelp ;;
      *)
        echo "Unknown option: $1" >&2
        showHelp ;;
    esac
  done
}

# Main execution controller
main() {
  parseArguments "$@"

  [ "$DO_DEPS" = true ] && installDependencies
  checkDevice
  confirmDevice
  initLog

  [ "$DO_DEBLOAT" = true ] && debloatPackages

  if [ "$DO_APPS" = true ]; then
    echo "Starting essentials downloads..."
    installKOReader
    installOlauncher
  fi

  [ "$DO_LAUNCHER" = true ] && promptSetDefaultLauncher
  [ "$DO_DISPLAY" = true ] && promptConfigureDisplay
}

# Execute main only if not sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
