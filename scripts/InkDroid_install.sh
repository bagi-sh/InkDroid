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
DO_TWEAKS=true

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

isPackageInstalled() {
  local pkg="$1"
  adb shell pm list packages --user 0 2>/dev/null | grep -q "^package:${pkg}$"
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

# Ensures base alternative app stores are present on the device
ensureBaseStores() {
  echo "Checking core app stores (F-Droid & Aurora Store)..."
 if ! isPackageInstalled "org.slavsquat.openboard" && ! isPackageInstalled "com.google.android.inputmethod.latin"; then
    echo "[INFO] No keyboard detected. Installing OpenBoard..."
    installOpenBoard
  elif isPackageInstalled "org.slavsquat.openboard"; then
    echo -e "\e[32m[OK] OpenBoard is already installed.\e[0m"
  fi

  if ! isPackageInstalled "org.fdroid.fdroid"; then
    echo "[INFO] F-Droid not found. Installing base store..."
    installFDroid
  else
    echo -e "\e[32m[OK] F-Droid is already installed.\e[0m"
  fi

  if ! isPackageInstalled "com.aurora.store"; then
    echo "[INFO] Aurora Store not found. Installing base store..."
    installAuroraStore
  else
    echo -e "\e[32m[OK] Aurora Store is already installed.\e[0m"
  fi
}

# Extract packages list from JSON using jq or python3 fallback
parseBlacklist() {
  if command -v jq >/dev/null 2>&1; then
    jq -r 'to_entries[] | .key as $cat | .value[] | "\($cat):\(.)"' "$JSON"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import json
with open('$JSON') as f:
    data = json.load(f)
for cat, items in data.items():
    for pkg in items:
        print(f'{cat}:{pkg}')
"
  else
    echo "Error: Neither jq nor python3 available to parse $JSON" >&2
    exit 1
  fi
}

# Uninstall bloatware packages for user 0
debloatPackages() {
  echo "Starting search and debloat apps..."

  # Validação de segurança sobre as lojas
  local has_fdroid=false
  local has_aurora=false
  local allow_google_debloat=false

  isPackageInstalled "org.fdroid.fdroid" && has_fdroid=true
  isPackageInstalled "com.aurora.store" && has_aurora=true

  if [ "$has_fdroid" = true ] && [ "$has_aurora" = true ]; then
    allow_google_debloat=true
    echo -e "\e[32m[SAFE] F-Droid and Aurora Store verified. Google Services debloat enabled.\e[0m"
  else
    echo -e "\e[33m[WARNING] F-Droid or Aurora Store missing. Skipping 'google_services' category to prevent soft-brick.\e[0m"
    echo "[WARN] Skipped Google Services debloat (F-Droid: $has_fdroid, Aurora: $has_aurora)" >> "$LOG_ACTIONS"
  fi

  parseBlacklist | while IFS=":" read -r categoria pacote; do
    [ -z "$pacote" ] && continue

    # Trava de segurança para a categoria google_services
    if [ "$categoria" = "google_services" ] && [ "$allow_google_debloat" = false ]; then
      echo -e "Processing: $pacote ... \e[33m[SKIPPED (No Alternative Store)]\e[0m"
      echo "[SKIP] Skipped $pacote due to missing alternative stores" >> "$LOG_ACTIONS"
      continue
    fi

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
  echo -e "\e[32m[FINISHED]\e[0m Debloat process completed"
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

installOpenBoard() {
  echo "Downloading OpenBoard Keyboard..."
  local url
  url=$(getReleaseApkUrl "openboard-team/openboard")

  if [ -n "$url" ]; then
    curl -fL "$url" -o /tmp/OpenBoard.apk
  fi

  if [ -s /tmp/OpenBoard.apk ]; then
    echo "[SUCCESS] Downloaded OpenBoard"
    echo "[SUCCESS] Downloaded OpenBoard" >> "$LOG_ACTIONS"
    echo "Installing and setting as default IME..."
    RESULT=$(adb install -r --user 0 /tmp/OpenBoard.apk < /dev/null 2>&1 || true)
    
    if echo "$RESULT" | grep -q "Success"; then
      echo "[SUCCESS] OpenBoard Installed"
      echo "[SUCCESS] OpenBoard Installed" >> "$LOG_ACTIONS"
      
      # Enable and activate OpenBoard IME via ADB
      adb shell ime enable org.slavsquat.openboard/.LatinIME >/dev/null 2>&1 || true
      adb shell ime set org.slavsquat.openboard/.LatinIME >/dev/null 2>&1 || true
      echo -e "\e[32m[OK] OpenBoard set as default keyboard.\e[0m"
    else
      echo "[ERROR] Something went wrong on OpenBoard Installation" >> "$LOG_ACTIONS"
      echo "Error. Process will continue without OpenBoard"
    fi
  else
    echo "Warning: could not download OpenBoard, continuing..."
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

# Download and install F-Droid
installFDroid() {
  echo "Downloading F-Droid..."
  local url
  url=$(getReleaseApkUrl "f-droid/fdroidclient")

  if [ -n "$url" ]; then
    curl -fL "$url" -o /tmp/FDroid.apk
  fi

  if [ -s /tmp/FDroid.apk ]; then
    echo "[SUCCESS] Downloaded F-Droid"
    echo "[SUCCESS] Downloaded F-Droid" >> "$LOG_ACTIONS"
    echo "Installing..."
    RESULT=$(adb install -r --user 0 /tmp/FDroid.apk < /dev/null 2>&1 || true)
    if echo "$RESULT" | grep -q "Success"; then
      echo "[SUCCESS] F-Droid Installed"
      echo "[SUCCESS] F-Droid Installed" >> "$LOG_ACTIONS"
    else
      echo "[ERROR] Something went wrong on F-Droid Installation" >> "$LOG_ACTIONS"
      echo "Error. Process will continue without F-Droid"
    fi
  else
    echo "Warning: could not download F-Droid, continuing..."
  fi
}

# Download and install Aurora Store
installAuroraStore() {
  echo "Downloading Aurora Store..."
  local url
  url=$(getReleaseApkUrl "AuroraOSS/AuroraStore")

  if [ -n "$url" ]; then
    curl -fL "$url" -o /tmp/AuroraStore.apk
  fi

  if [ -s /tmp/AuroraStore.apk ]; then
    echo "[SUCCESS] Downloaded Aurora Store"
    echo "[SUCCESS] Downloaded Aurora Store" >> "$LOG_ACTIONS"
    echo "Installing..."
    RESULT=$(adb install -r --user 0 /tmp/AuroraStore.apk < /dev/null 2>&1 || true)
    if echo "$RESULT" | grep -q "Success"; then
      echo "[SUCCESS] Aurora Store Installed"
      echo "[SUCCESS] Aurora Store Installed" >> "$LOG_ACTIONS"
    else
      echo "[ERROR] Something went wrong on Aurora Store Installation" >> "$LOG_ACTIONS"
      echo "Error. Process will continue without Aurora Store"
    fi
  else
    echo "Warning: could not download Aurora Store, continuing..."
  fi
}

# Download and install Mihon
installMihon() {
  echo "Downloading Mihon..."
  local url
  # Tenta primeiro a build para arquiteturas de 32 bits (comum em tablets legados) ou genérica
  url=$(getReleaseApkUrl "mihonapp/mihon" "armv7")
  [ -z "$url" ] && url=$(getReleaseApkUrl "mihonapp/mihon" "universal")
  [ -z "$url" ] && url=$(getReleaseApkUrl "mihonapp/mihon")

  if [ -n "$url" ]; then
    curl -fL "$url" -o /tmp/Mihon.apk
  fi

  if [ -s /tmp/Mihon.apk ]; then
    echo "[SUCCESS] Downloaded Mihon"
    echo "[SUCCESS] Downloaded Mihon" >> "$LOG_ACTIONS"
    echo "Installing..."
    RESULT=$(adb install -r --user 0 /tmp/Mihon.apk < /dev/null 2>&1 || true)
    if echo "$RESULT" | grep -q "Success"; then
      echo "[SUCCESS] Mihon Installed"
      echo "[SUCCESS] Mihon Installed" >> "$LOG_ACTIONS"
    else
      echo "[ERROR] Something went wrong on Mihon Installation" >> "$LOG_ACTIONS"
      echo "Error. Process will continue without Mihon"
    fi
  else
    echo "Warning: could not download Mihon, continuing..."
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
  # adb shell settings put screen_brightness_mode 0

  if [ ${#refreshlist[@]} -gt 0 ] && [ -n "${refreshlist[0]}" ]; then
    echo "limiting refresh rate to ${refreshlist[0]} Hz..."
    adb shell settings put system peak_refresh_rate "${refreshlist[0]}"
    adb shell settings put system min_refresh_rate "${refreshlist[0]}"
  fi

  if [ "$profile" -eq 1 ]; then
    echo "Activating global blue light filter..."
    adb shell settings put secure night_display_activated 1
    adb shell settings put secure night_display_color_temperature 2096
  else
    echo "Activating monochromatic display..."
    adb shell settings put secure accessibility_display_daltonizer_enabled 1
    adb shell settings put secure accessibility_display_daltonizer 0
    adb shell settings put secure acessibility_display_daltonizer_enable 1 >/dev/null 2>&1 || true
    adb shell settings put secure acessibility_display_daltonizer 0 >/dev/null 2>&1 || true
    adb shell settings put secure night_display_activated 1
    adb shell settings put secure night_display_color_temperature 2096
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

# Aplly optimzed configs to the battery
applyFrameworkTweaks() {
  echo "Applying framework tweaks and power settings..."

  # Ajustes diretos (Globais, Sistema e Segurança)
  adb shell settings put global always_finish_activities 1
  adb shell settings put global low_power 1
  adb shell settings put global low_power_trigger_level 100
  adb shell settings put system screen_off_timeout 1800000
  adb shell settings put global heads_up_notifications_enabled 0
  adb shell settings put global zen_mode 1
  adb shell settings put global wifi_scan_always_enabled 0
  adb shell settings put global ble_scan_always_enabled 0
  adb shell settings put global auto_sync 0
  adb shell settings put system haptic_feedback_enabled 0
  adb shell settings put system haptic_feedback_intensity 0
  adb shell settings put system sound_effects_enabled 0
  adb shell settings put system lockscreen_sounds_enabled 0
  adb shell settings put secure voice_interaction_service \"\"
  adb shell settings put secure assistant \"\"

  echo "[SUCCESS] Base framework tweaks applied."
  echo "[SUCCESS] Base framework tweaks applied." >> "$LOG_ACTIONS"

  # Validação interativa para configurações sensíveis
  echo "--------------------------------------------------"
  echo "Interactive validation for optional settings:"

  # 1. Validação de Dados Móveis
  read -p "Do you want to disable Mobile Data? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    adb shell settings put global mobile_data 0
    echo -e "\e[32m[APPLIED] Mobile data disabled.\e[0m"
    echo "[SUCCESS] Mobile data disabled." >> "$LOG_ACTIONS"
  else
    echo -e "\e[33m[SKIPPED] Mobile data status preserved.\e[0m"
    echo "[INFO] Mobile data tweak skipped by user." >> "$LOG_ACTIONS"
  fi

  # 2. Validação de Atualizações Automáticas OTA
  read -p "Do you want to disable Automatic OTA Updates? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    adb shell settings put global ota_disable_automatic_update 1
    echo -e "\e[32m[APPLIED] Automatic OTA updates disabled.\e[0m"
    echo "[SUCCESS] Automatic OTA updates disabled." >> "$LOG_ACTIONS"
  else
    echo -e "\e[33m[SKIPPED] OTA automatic updates preserved.\e[0m"
    echo "[INFO] OTA update tweak skipped by user." >> "$LOG_ACTIONS"
  fi

  echo "--------------------------------------------------"
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

  ensureBaseStores

  [ "$DO_DEBLOAT" = true ] && debloatPackages

if [ "$DO_APPS" = true ]; then
    echo "Starting optional reader apps installation..."
    
    if ! isPackageInstalled "org.koreader.launcher"; then
      installKOReader
    else
      echo -e "\e[32m[OK] KOReader is already installed.\e[0m"
    fi

    if ! isPackageInstalled "app.mihon"; then
      installMihon
    else
      echo -e "\e[32m[OK] Mihon is already installed.\e[0m"
    fi

    if ! isPackageInstalled "app.olauncher"; then
      installOlauncher
    else
      echo -e "\e[32m[OK] Olauncher is already installed.\e[0m"
    fi
  fi

  [ "$DO_LAUNCHER" = true ] && promptSetDefaultLauncher
  [ "$DO_DISPLAY" = true ] && promptConfigureDisplay
  [ "$DO_TWEAKS" = true ] && applyFrameworkTweaks

}

# Execute main only if not sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
