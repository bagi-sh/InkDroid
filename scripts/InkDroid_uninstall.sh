#!/usr/bin/env bash
set -e

# Repository and environment variables
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_ACTIONS="$REPO/restorelog.txt"
JSON="$REPO/dependences/blacklist.json"

DO_PACKAGES=true
DO_APPS=true
DO_DISPLAY=true
AUTO_CONFIRM=false

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
    read -r -p "Continue restoration on $MODEL? Y/n " yn
    case "$yn" in
      [Yy]* | "" ) break;;
      [Nn]* ) exit 0;;
      * ) break;;
    esac
  done
}

# Initialize restoration report log
initLog() {
  if [ ! -f "$JSON" ]; then
    echo -e "\e[31m[ERROR]\e[0m JSON blacklist file not found in: $JSON"
    exit 1
  fi

  echo "=== RESTORATION REPORT ===" > "$LOG_ACTIONS"
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

# Reinstall debloated system packages for user 0
restorePackages() {
  echo "Starting package restoration..."

  parseBlacklist | while read -r pacote; do
    [ -z "$pacote" ] && continue

    echo -n "Restoring: $pacote ... "
    RESULT=$(adb shell cmd package install-existing "$pacote" < /dev/null 2>&1 || adb shell pm install-existing "$pacote" < /dev/null 2>&1 || true)

    if echo "$RESULT" | grep -q -E "installed for user|Package .* installed"; then
      echo -e "\e[32m[RESTORED]\e[0m"
      echo "[SUCCESS] Restored: $pacote" >> "$LOG_ACTIONS"
    elif echo "$RESULT" | grep -q -E "already installed|Success"; then
      echo -e "\e[32m[ALREADY ACTIVE]\e[0m"
      echo "[INFO] Already active: $pacote" >> "$LOG_ACTIONS"
    else
      echo -e "\e[33m[SKIPPED]\e[0m"
      echo "[SKIPPED] Package $pacote: $RESULT" >> "$LOG_ACTIONS"
    fi
  done

  echo "--------------------------------------------------"
  echo -e "\e[32m[FINISHED]\e[0m Packages restoration finished"
}

# Remove installed e-reader apps and clear custom launcher role
removeApps() {
  echo "Resetting default launcher..."
  adb shell cmd role clear-role-holders android.app.role.HOME >/dev/null 2>&1 || true

  echo "Removing KOReader..."
  adb shell pm uninstall org.koreader.launcher >/dev/null 2>&1 || true
  adb shell pm uninstall com.koreader.launcher >/dev/null 2>&1 || true
  echo "[SUCCESS] Removed KOReader" >> "$LOG_ACTIONS"

  echo "Removing Olauncher..."
  adb shell pm uninstall app.olauncher >/dev/null 2>&1 || true
  echo "[SUCCESS] Removed Olauncher" >> "$LOG_ACTIONS"

  echo "--------------------------------------------------"
  echo -e "\e[32m[FINISHED]\e[0m Installed e-reader apps removed"
}

# Restore default animation scales, refresh rate and color profile
restoreDisplay() {
  echo "Restoring animation scales..."
  adb shell settings put global window_animation_scale 1
  adb shell settings put global transition_animation_scale 1
  adb shell settings put global animator_duration_scale 1

  echo "Resetting refresh rate limits..."
  adb shell settings delete system peak_refresh_rate >/dev/null 2>&1 || true
  adb shell settings delete system min_refresh_rate >/dev/null 2>&1 || true

  echo "Disabling display filters..."
  adb shell settings put secure accessibility_display_daltonizer_enabled 0 >/dev/null 2>&1 || true
  adb shell settings put secure accessibility_display_daltonizer -1 >/dev/null 2>&1 || true
  adb shell settings put secure acessibility_display_daltonizer_enable 0 >/dev/null 2>&1 || true
  adb shell settings put secure acessibility_display_daltonizer 0 >/dev/null 2>&1 || true
  adb shell settings put secure night_display_activated 0 >/dev/null 2>&1 || true
  adb shell settings delete secure night_display_color_temperature >/dev/null 2>&1 || true

  echo "--------------------------------------------------"
  echo -e "\e[32m[FINISHED]\e[0m Display settings restored to defaults"
}

# Print command line help
showHelp() {
  cat << 'EOF'
Usage: InkDroid_uninstall.sh [OPTIONS]

Options:
  --only-packages   Restore only debloated packages from blacklist
  --only-apps       Remove only installed apps (KOReader and Olauncher)
  --only-display    Restore only default display and animation settings
  --skip-packages   Skip restoring debloated packages
  --skip-apps       Skip removing installed apps
  --skip-display    Skip restoring display settings
  -y, --yes         Non-interactive mode (auto-confirm prompts)
  -h, --help        Show this help message
EOF
  exit 0
}

# Parse command line flags
parseArguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --only-packages)
        DO_APPS=false; DO_DISPLAY=false; DO_PACKAGES=true; shift ;;
      --only-apps)
        DO_PACKAGES=false; DO_DISPLAY=false; DO_APPS=true; shift ;;
      --only-display)
        DO_PACKAGES=false; DO_APPS=false; DO_DISPLAY=true; shift ;;
      --skip-packages)
        DO_PACKAGES=false; shift ;;
      --skip-apps)
        DO_APPS=false; shift ;;
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

  checkDevice
  confirmDevice
  initLog

  [ "$DO_PACKAGES" = true ] && restorePackages
  [ "$DO_APPS" = true ] && removeApps
  [ "$DO_DISPLAY" = true ] && restoreDisplay
}

# Execute main only if not sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
