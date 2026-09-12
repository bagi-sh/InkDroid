#!/bin/bash
# Define as variavéis do código
REPO="/home/$USER/InkDroid"
PACKAGES="android-tools curl bc jq"
LOG_ACTIONS="$REPO/debloatlog.txt"
touch "$LOG_ACTIONS"
JSON="$REPO/dependences/blacklist.json"

installDependencies() {
	if [ -x "$(command -v apt-get)" ]; then 
		sudo apt-get update && sudo apt-get install -y $PACKAGES
	elif [ -x "$(command -v dnf)" ]; then
		sudo dnf install -y $PACKAGES
	elif [ -x "$(command -v pacman)" ]; then
		sudo pacman -Sy --noconfirm $PACKAGES
	elif [ -x "$(command -v zypper)" ]; then
    sudo zypper install -y $PACKAGES
	else 
		echo "ERROR: couldn't install dependeces packages, please install $PACKAGES manually."
		exit 1 
	fi				 	 
}

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

installDependencies()
# Verify if only one device is connected 
DEVICE_CHECK=$(adb devices | grep -v "List of devices attached" | grep "device$" | wc -l)

if [ "$DEVICE_CHECK" -eq 1 ]; then
    echo "Status: Compatible device found."

    MODEL=$(adb shell getprop ro.product.model | tr -d '\r')

    echo "Device Identified"

elif [ "$DEVICE_CHECK" -gt 1 ]; then
    echo "Error: More than one device connected, please keep only one"
    exit 1
else
    echo "Error: cant found any compatible device."
    echo "Make sure debugging USB is on and with your PC checked as known"
    exit 1
fi

ANDROID_VER=$(adb shell getprop ro.build.version.release)
VENDOR=$(adb shell getprop ro.product.manufacturer)

echo -e "\e[32m[CONNECTED]\e[0m Device Detected whitout problems!"
echo "--------------------------------------------------"
echo " Vendor:    $VENDOR"
echo " Model:     $MODEL"
echo " Android:   $ANDROID_VER"
echo "--------------------------------------------------"

# DO A VERIFICATION HERE (Y/N)

while true; do
    read -p "Continue script in the $MODEL? Y/n " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) break;;
    esac
done

# Validate JSON file path
if [ ! -f "$JSON" ]; then
    echo -e "\e[31m[ERROR]\e[0m JSON blacklist file not found in: $JSON"
    exit 1
fi

# Inicializa o arquivo de log/relatório
echo "=== SCRIPT RELATORY ===" > "$LOG_ACTIONS"
echo "DEVICE: $VENDOR $MODEL (Android $ANDROID_VER)" >> "$LOG_ACTIONS"
echo "DATE: $(date)" >> "$LOG_ACTIONS"
echo "---------------------------------" >> "$LOG_ACTIONS"

# --- Execução do Processo de Otimização (Parsing do JSON) ---

echo "Iniciando a varredura e remoção dos pacotes..."

# O jq extrai os arrays de todas as categorias do JSON e os formata em uma lista plana
jq -r '.[] | .[]' "$JSON" | while read -r pacote; do
    
    # Ignora linhas em branco por segurança
    [ -z "$pacote" ] && continue
    
    echo -n "Processando: $pacote ... "

    RESULT=$(adb shell pm uninstall -k --user 0 "$pacote" < /dev/null 2>&1)

    # Valida o resultado do comando enviado ao Android
    if echo "$RESULT" | grep -q "Success"; then
        echo -e "\e[32m[REMOVED]\e[0m"
        echo "[SUCESS] Unistalled: $pacote" >> "$LOG_ACTIONS"
    elif echo "$RESULT" | grep -q "not installed"; then
        echo -e "\e[33m[PACKAGE NOT FOUND]\e[0m"
        echo "[INFO] Dont find package: $pacote" >> "$LOG_ACTIONS"
    else
        echo -e "\e[31m[ERROR]\e[0m ($RESULT)"
        echo "[FAIL] Error on trying $pacote: $RESULT" >> "$LOG_ACTIONS"
    fi

done

echo "--------------------------------------------------"
echo -e "\e[32m[FINISHED]\e[0m All of blacklist apps are uninstalled"

echo "Starting essetials downloads..."

curl -fL "$(curl fsSL https://api.github.com/repos/koreader/koreader/releases/latest | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url' | head -n 1)"  -o /tmp/Koreader.apk
if [ -e /tmp/Koreader.apk ]; then
  echo "[SUCESS] Downloaded Koreader" && echo "[SUCESS] Downloaded Koreader" >> "$LOG_ACTIONS"
  echo "Installing..."
  RESULT=$(adb install -r --user 0 /tmp/Koreader.apk < /dev/null 2>&1)
  if echo "$RESULT" | grep -q "Success"; then
    echo "[SUCESS] Koreader Installed" &&  echo "[SUCESS] Koreader Installed" >> "$LOG_ACTIONS"
  else
    echo "[ERROR] Something went wrong on Koreader Installation" >> "$LOG_ACTIONS"
    echo "Error. Process will continue withot Koreader"
    fi
fi

curl -fL "$(curl -fsSL https://api.github.com/repos/tanujnotes/Olauncher/releases/latest | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url' | head -n 1)" -o /tmp/olauncher.apk
if [ -e /tmp/olauncher.apk ]; then
  echo "[SUCESS] Downloaded Olauncher" && echo "[SUCESS] Downloaded Olauncher" >> "$LOG_ACTIONS"
  echo "Installing..."
  RESULT=$(adb install -r --user 0 /tmp/olauncher.apk < /dev/null 2>&1)
  if echo "$RESULT" | grep -q "Success"; then
    echo "[SUCESS] Koreader Installed" &&  echo "[SUCESS] Koreader Installed" >> "$LOG_ACTIONS"
  else
    echo "[ERROR] Something went wrong on Olauncher Installation" >> "$LOG_ACTIONS"
    echo "Error. Process will continue withot Olauncher"
    fi
fi

while true; do
  read -p "Do you wish to change the default launcher? Y/n" yn
    case $yn in
      [Yy]* ) setDefaultLauncher(); break;;
      [Nn]* ) break;;
      * ) setDefaultLauncher; break;;
    esac
done

