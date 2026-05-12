#!/bin/bash
# Define as variavéis do código
REPO_LOCAL=$(/home/$USER/android_e-reader_project)
PACKAGES=$(android-tools curl bc)

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
    MODELO_DISPOSITIVO=$(adb shell getprop ro.product.model | tr -d '\r')

    echo "Modelo identificado: $MODELO_DISPOSITIVO"
    
    # Exemplo de uso da variável
    echo "Iniciando procedimentos para o modelo $MODELO_DISPOSITIVO..."

elif [ "$DEVICE_CHECK" -gt 1 ]; then
    echo "Erro: Mais de um dispositivo conectado. Desconecte os excedentes."
    exit 1
else
    echo "Erro: Nenhum dispositivo encontrado ou não autorizado."
    echo "Certifique-se de que a Depuração USB está ativa e o computador foi autorizado."
    exit 1
fi
