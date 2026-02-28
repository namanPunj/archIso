#!/bin/bash
# ==========================================
# ARISE OS - GITHUB POST-INSTALL MODULE
# ==========================================
USER_NAME=$1
USER_PASS=$2
ROOT_PASS=$3

CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'
LOG_FILE="/tmp/arise_post_install.log"

run_task() {
    local msg="$1"
    shift
    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    local width=20
    local progress=0
    
    tput civis
    while kill -0 $pid 2>/dev/null; do
        progress=$((progress + (100 - progress) / 20))
        if [ $progress -gt 99 ]; then progress=99; fi
        local filled=$((progress * width / 100))
        local empty=$((width - filled))
        local bar=$(printf "%${filled}s" | tr ' ' '█')
        local space=$(printf "%${empty}s" | tr ' ' '░')
        printf "\r\e[K${BLUE}[${CYAN}%s%s${BLUE}]${NC} %3d%% | ${YELLOW}⚙${NC} %s" "$bar" "$space" "$progress" "$msg"
        sleep 0.2
    done
    wait $pid
    local status=$?
    tput cnorm

    local full_bar=$(printf "%${width}s" | tr ' ' '█')
    if [ $status -eq 0 ]; then
        printf "\r\e[K${BLUE}[${GREEN}%s${BLUE}]${NC} 100%% | ${GREEN}✔${NC} %s\n" "$full_bar" "$msg"
    else
        printf "\r\e[K${BLUE}[${RED}%s${BLUE}]${NC} ERR! | ${RED}✘${NC} %s\n" "$full_bar" "$msg"
    fi
}

echo -e "\n${CYAN}--- Finalizing User & Yay Setup ---${NC}"
run_task "Creating User ($USER_NAME)" useradd -m -G wheel "$USER_NAME"
run_task "Setting User Password" bash -c "echo '$USER_NAME:$USER_PASS' | chpasswd"
run_task "Setting Root Password" bash -c "echo 'root:$ROOT_PASS' | chpasswd"

# Grant temporary sudo without password for Yay build
run_task "Bypassing Sudo Prompt" bash -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel_temp"

run_task "Cloning Yay" su - "$USER_NAME" -c "git clone https://aur.archlinux.org/yay.git /tmp/yay-repo"
run_task "Compiling Yay" su - "$USER_NAME" -c "cd /tmp/yay-repo && makepkg -si --noconfirm"
run_task "Cleaning up Yay Cache" bash -c "rm -rf /tmp/yay-repo"

run_task "Creating ~/pFiles" su - "$USER_NAME" -c "mkdir -p ~/pFiles/yay-builds"
run_task "Routing Yay Config" bash -c "echo 'BUILDDIR=/home/$USER_NAME/pFiles/yay-builds' >> /etc/makepkg.conf"

run_task "Securing Sudo Access" bash -c "rm -f /etc/sudoers.d/wheel_temp && echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers"

# Optional Apps
LINK_3_APPS="https://raw.githubusercontent.com/namanPunj/archIso/refs/heads/main/optional_apps"
curl -sfL "$LINK_3_APPS" -o /tmp/apps.txt

if [[ -s /tmp/apps.txt ]] && ! grep -iq "<!DOCTYPE" /tmp/apps.txt; then
    echo -e "\n${CYAN}--- Optional Applications ---${NC}"
    while IFS='|' read -r app desc; do
        [[ "$app" =~ ^#.*$ ]] || [[ -z "$app" ]] && continue
        app_clean=$(echo "$app" | xargs)
        desc_clean=$(echo "$desc" | xargs)

        echo -e "\n  ${BLUE}App:${NC} $app_clean \n  ${YELLOW}Info:${NC} $desc_clean"
        read -p "  [?] Install? (y/n): " INSTALL_APP

        if [[ "$INSTALL_APP" == "y" ]]; then
            run_task "Installing $app_clean" su - "$USER_NAME" -c "yay -S --noconfirm $app_clean"
        fi
    done < /tmp/apps.txt
fi
