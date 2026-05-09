#!/bin/bash

# 1. Verifica se há exatamente um dispositivo conectado e autorizado
# O comando 'adb devices' lista os IDs. Filtramos a linha do cabeçalho e linhas vazias.
DEVICE_CHECK=$(adb devices | grep -v "List of devices attached" | grep "device$" | wc -l)

if [ "$DEVICE_CHECK" -eq 1 ]; then
    echo "Status: Dispositivo compatível encontrado."

    # 2. Extrai o modelo do dispositivo usando getprop
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