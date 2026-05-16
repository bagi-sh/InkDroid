#!/bin/bash
# Define as variavéis do código
REPO=$(/home/$USER/android_e-reader_project)
PACKAGES=$(android-tools curl bc jq)
ANDROID_VER=$(adb shell getprop ro.build.version.release)
FABRICANTE=$(adb shell getprop ro.product.manufacturer)
LOG_REMOVACOES=($REPO/scripts/debloatlog.txt)
JSON=($REPO/Installation\ Resources/blacklis.json)
# Instalando dependências 
install_dependencies() {
	if [ -x "$(command -v apt-get)"]; then 
		sudo apt-get update && sudo apt-get install -y $PACKAGES
	elif [ -x "$(command -v dnf)"]; then
		sudo dnf install -y $PACKAGES
	elif [-x "$(command -v pacman)"]; then
		sudo pacman -Sy --no-confirm $PACKAGES
	elif [ -x "$(command -v zypper)" ]; then
        	sudo zypper install -y $PACKAGES
	else 
		echo "ERRO: Falha ao identificar gerenciador de pacotes. verifique as permissões ou instale manualmente"
		exit 1 
	fi
}

# Verifica se há exatamente um dispositivo conectado e autorizado
# O comando 'adb devices' lista os IDs. Filtramos a linha do cabeçalho e linhas vazias.
DEVICE_CHECK=$(adb devices | grep -v "List of devices attached" | grep "device$" | wc -l)

if [ "$DEVICE_CHECK" -eq 1 ]; then
    echo "Status: Dispositivo compatível encontrado."

    # Extrai o modelo do dispositivo usando getprop
    # O comando limpa caracteres de escape (\r) comuns em saídas do Android
    MODELO=$(adb shell getprop ro.product.model | tr -d '\r')

    echo "Dispositivo identificado"
    
    # Exemplo de uso da variável
    echo "Iniciando procedimentos para o dispositivo"

elif [ "$DEVICE_CHECK" -gt 1 ]; then
    echo "Erro: Mais de um dispositivo conectado. Desconecte os excedentes."
    exit 1
else
    echo "Erro: Nenhum dispositivo encontrado ou não autorizado."
    echo "Certifique-se de que a Depuração USB está ativa e o computador foi autorizado."
    exit 1
fi

echo -e "\e[32m[CONECTADO]\e[0m Dispositivo detectado com sucesso!"
echo "--------------------------------------------------"
echo " Fabricante: $FABRICANTE"
echo " Modelo:     $MODELO"
echo " Android:    $ANDROID_VER"
echo "--------------------------------------------------"

# Inicializa o arquivo de log/relatório
echo "=== RELATÓRIO DE DEBLOAT ===" > "$LOG_REMOVACOES"
echo "Apareilho: $FABRICANTE $MODELO (Android $ANDROID_VER)" >> "$LOG_REMOVACOES"
echo "Data da execução: $(date)" >> "$LOG_REMOVACOES"
echo "---------------------------------" >> "$LOG_REMOVACOES"

# --- Execução do Processo de Otimização (Parsing do JSON) ---

echo "Iniciando a varredura e remoção dos pacotes..."

# O jq extrai os arrays de todas as categorias do JSON e os formata em uma lista plana
jq -r '.[] | .[]' "$JSON" | while read -r pacote; do
    
    # Ignora linhas em branco por segurança
    [ -z "$pacote" ] && continue
    
    echo -n "Processando: $pacote ... "
    
    # Executa a desinstalação a nível de usuário comum (User 0) sem necessidade de Root
    # Captura a saída de erro padrão para evitar mensagens poluídas no terminal
    RESULTADO=$(adb shell pm uninstall -k --user 0 "$pacote" 2>&1)
    
    # Valida o resultado do comando enviado ao Android
    if echo "$RESULTADO" | grep -q "Success"; then
        echo -e "\e[32m[REMOVIDO]\e[0m"
        echo "[SUCESSO] Pacote removido: $pacote" >> "$LOG_REMOVACOES"
    elif echo "$RESULTADO" | grep -q "not installed"; then
        echo -e "\e[33m[NÃO ENCONTRADO]\e[0m"
        echo "[INFO] Pacote ausente na ROM padrão: $pacote" >> "$LOG_REMOVACOES"
    else
        echo -e "\e[31m[FALHA]\e[0m ($RESULTADO)"
        echo "[FALHA] Erro ao remover $pacote: $RESULTADO" >> "$LOG_REMOVACOES"
    fi

done

echo "--------------------------------------------------"
echo -e "\e[32m[CONCLUÍDO]\e[0m Otimização finalizada!"
echo "O relatório detalhado foi salvo em: ./$LOG_REMOVACOES"
