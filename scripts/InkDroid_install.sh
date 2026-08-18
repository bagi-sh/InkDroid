#!/bin/bash
# Define as variavéis do código
REPO="/home/$USER/InkDroid"
PACKAGES="android-tools curl bc jq"
LOG_ACTIONS="$REPO/debloatlog.txt"
touch "$LOG_ACTIONS"
JSON="$REPO/dependences/blacklist.json"

install_dependencies() {
	if [ -x "$(command -v apt-get)" ]; then 
		sudo apt-get update && sudo apt-get install -y $PACKAGES
	elif [ -x "$(command -v dnf)" ]; then
		sudo dnf install -y $PACKAGES
	elif [ -x "$(command -v pacman)" ]; then
		sudo pacman -Sy --noconfirm $PACKAGES
	elif [ -x "$(command -v zypper)" ]; then
    sudo zypper install -y $PACKAGES
	else 
		echo "ERRO: Falha ao identificar gerenciador de pacotes. verifique as permissões ou instale manualmente"
		exit 1 
	fi				 	 
}

install_dependencies()
# Verifica se há exatamente um dispositivo conectado e autorizado
DEVICE_CHECK=$(adb devices | grep -v "List of devices attached" | grep "device$" | wc -l)

if [ "$DEVICE_CHECK" -eq 1 ]; then
    echo "Status: Dispositivo compatível encontrado."

    MODEL=$(adb shell getprop ro.product.model | tr -d '\r')

    echo "Dispositivo identificado"
    
    echo "Iniciando procedimentos para o dispositivo"

elif [ "$DEVICE_CHECK" -gt 1 ]; then
    echo "Erro: Mais de um dispositivo conectado. Desconecte os excedentes."
    exit 1
else
    echo "Erro: Nenhum dispositivo encontrado ou não autorizado."
    echo "Certifique-se de que a Depuração USB está ativa e o computador foi autorizado."
    exit 1
fi

ANDROID_VER=$(adb shell getprop ro.build.version.release)
VENDOR=$(adb shell getprop ro.product.manufacturer)

echo -e "\e[32m[CONECTADO]\e[0m Dispositivo detectado com sucesso!"
echo "--------------------------------------------------"
echo " Fabricante: $VENDOR"
echo " Modelo:     $MODEL"
echo " Android:    $ANDROID_VER"
echo "--------------------------------------------------"

# Valida se o arquivo JSON corrigido realmente existe no caminho absoluto
if [ ! -f "$JSON" ]; then
    echo -e "\e[31m[ERRO]\e[0m Arquivo JSON não encontrado em: $JSON"
    exit 1
fi

# Inicializa o arquivo de log/relatório
echo "=== RELATÓRIO DE DEBLOAT ===" > "$LOG_ACTIONS"
echo "Aparelho: $VENDOR $MODEL (Android $ANDROID_VER)" >> "$LOG_ACTIONS"
echo "Data da execução: $(date)" >> "$LOG_ACTIONS"
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
echo -e "\e[32m[CONCLUÍDO]\e[0m Otimização finalizada!"
echo "O relatório detalhado foi salvo em: $LOG_ACTIONS"

echo "Starting Download for apps"

curl -fL "$(curl fsSL https://api.github.com/repos/koreader/koreader/releases/latest | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url' | head -n 1)"  -o ./Koreader.apk
if [ -e ./Koreader.apk ]; then
  echo "[SUCESS] Downloaded Koreader" && echo "[SUCESS] Downloaded Koreader" >> "$LOG_ACTIONS"
  echo "Installing..."
  RESULT=$(adb install -r --user 0 ./Koreader.apk < /dev/null 2>&1)
  if echo "$RESULT" | grep -q "Success"; then
    echo "[SUCESS] Koreader Installed" &&  echo "[SUCESS] Koreader Installed" >> "$LOG_ACTIONS"
  else
    echo "[ERROR] Something went wrong on Koreader Installation" >> "$LOG_ACTIONS"
    echo "Error. Process will continue withot Koreader"
    fi
fi

curl -fL "$(curl -fsSL https://api.github.com/repos/tanujnotes/Olauncher/releases/latest | jq -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url' | head -n 1)" -o olauncher.apk
if [ -e ./olauncher.apk ]; then
  echo "[SUCESS] Downloaded Olauncher" && echo "[SUCESS] Downloaded Olauncher" >> "$LOG_ACTIONS"
  echo "Installing..."
  RESULT=$(adb install -r --user 0 ./olauncher.apk < /dev/null 2>&1)
  if echo "$RESULT" | grep -q "Success"; then
    echo "[SUCESS] Koreader Installed" &&  echo "[SUCESS] Koreader Installed" >> "$LOG_ACTIONS"
  else
    echo "[ERROR] Something went wrong on Olauncher Installation" >> "$LOG_ACTIONS"
    echo "Error. Process will continue withot Olauncher"
    fi
fi

