#!/bin/bash
# ==========================================
# ARISE OS - REMOTE POST-INSTALL PAYLOAD
# ==========================================
USER_NAME="$1"

echo "=========================================="
echo " STAGE 1: COMPILING YAY (AUR HELPER)"
echo "=========================================="
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel_temp

su - "$USER_NAME" -c "git clone https://aur.archlinux.org/yay.git /tmp/yay-repo"
su - "$USER_NAME" -c "cd /tmp/yay-repo && makepkg -si --noconfirm"
rm -rf /tmp/yay-repo

su - "$USER_NAME" -c "mkdir -p ~/pFiles/yay-builds"
echo "BUILDDIR=/home/$USER_NAME/pFiles/yay-builds" >> /etc/makepkg.conf
rm -f /etc/sudoers.d/wheel_temp

echo "=========================================="
echo " STAGE 2: INSTALLING GUI & DRIVERS"
echo "=========================================="
curl -sfL "https://raw.githubusercontent.com/namanPunj/archIso/refs/heads/main/recommended_package" -o /tmp/extra.txt
EXTRA_DATA=$(cat /tmp/extra.txt | sed 's/#.*//' | sed '/^\s*$/d')

for pkg in $EXTRA_DATA; do
    echo "-> Installing $pkg..."
    pacman -S --noconfirm --ask 4 "$pkg"
done

echo "=========================================="
echo " STAGE 3: ENABLING SERVICES"
echo "=========================================="
systemctl enable sddm
systemctl enable power-profiles-daemon 2>/dev/null || true

echo "=========================================="
echo " POST-INSTALLATION COMPLETE!"
echo "=========================================="
