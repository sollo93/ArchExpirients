#!/bin/bash

DISK="/dev/sda"
SWAP_SIZE="6G"  # Размер swap-раздела, можно изменить

echo "--- Начинаем установку Arch Linux с Bspwm ---"
echo "Убедитесь, что вы загрузились в UEFI режиме и подключены к интернету."
read -p "Нажмите Enter для продолжения или Ctrl+C для отмены..."

# 1. Разметка диска (замените /dev/sda на ваш диск!)
echo "Разметка диска: $DISK"
read -p "ВНИМАНИЕ: Все данные на $DISK будут УДАЛЕНЫ! Продолжить? (y/N): " confirm_wipe
if [[ ! "$confirm_wipe" =~ ^[yY]$ ]]; then
    echo "Отмена установки."
    exit 1
fi

parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on

# Создаем swap-раздел
parted -s "$DISK" mkpart primary linux-swap 512MiB $((512 + $(echo $SWAP_SIZE | sed 's/G//')) )MiB

# Остальное пространство под корень
parted -s "$DISK" mkpart primary ext4 $((512 + $(echo $SWAP_SIZE | sed 's/G//')) )MiB 100%

mkfs.fat -F32 "${DISK}1"
mkswap "${DISK}2"
swapon "${DISK}2"
mkfs.ext4 "${DISK}3"

# 2. Монтирование разделов
mount "${DISK}3" /mnt
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# 3. Установка базовой системы
echo "Установка базовой системы Arch Linux..."
pacstrap /mnt base base-devel linux linux-firmware vim networkmanager grub efibootmgr

# 4. Генерация fstab (с учётом swap)
genfstab -U /mnt >> /mnt/etc/fstab

# 5. Chroot в новую систему
echo "Chroot в новую систему для дальнейшей настройки..."
arch-chroot /mnt /bin/bash <<EOF_CHROOT
    # 5.1 Настройка часового пояса и локали
    ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
    hwclock --systohc
    
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    
    # 5.2 Имя хоста
    read -p "Введите имя хоста (hostname): " HOSTNAME
    echo "$HOSTNAME" > /etc/hostname
    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "::1       localhost" >> /etc/hosts
    echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts
    
    # 5.3 Пароль root
    echo "Установка пароля для пользователя root..."
    passwd
    
    # 5.4 Добавление пользователя
    read -p "Введите имя нового пользователя: " USERNAME
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "Установка пароля для пользователя $USERNAME..."
    passwd "$USERNAME"
    
    # 5.5 Настройка sudo
    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
    
    # 5.6 Установка и настройка GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux
    grub-mkconfig -o /boot/grub/grub.cfg
    
    # 5.7 Включение сетевого менеджера
    systemctl enable NetworkManager

    # 5.8 Установка графического окружения.
    echo "Установка Xorg, bspwm, polybar, st, micro, thunar, rofi..."
    pacman -Syu --noconfirm xorg-server xorg-xinit xorg-apps xf86-video-intel bspwm sxhkd polybar picom rofi alacritty micro thunar gvfs gvfs-smb gvfs-afc gvfs-google gvfs-mtp gvfs-nfs git base-devel

    # 5.9 Установка AUR-хелпера yay
    echo "Установка AUR-хелпера yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd /
    rm -rf /tmp/yay

    # 5.10 Установка VSCode и инструментов разработки
    echo "Установка VSCode, Python, Git..."
    yay -S --noconfirm visual-studio-code-bin
    pacman -S --noconfirm python python-pip git

    # 5.11 Установка Yandex Browser и rclone
    echo "Установка Yandex Browser (через AUR) и rclone..."
    yay -S --noconfirm yandex-browser-beta-bin
    pacman -S --noconfirm rclone

    # 5.12 Установка onedrive (если нужен)
    echo "Установка onedrive"
    yay -S --noconfirm onedrive

    # 5.13 Автоматическая настройка bspwm, polybar, sxhkd через dotfiles
    echo "Клонирование и установка dotfiles (Zproger)..."
    su - "$USERNAME" -c "git clone https://github.com/Zproger/bspwm-dotfiles.git /home/$USERNAME/.config/bspwm-dotfiles"
    su - "$USERNAME" -c "cd /home/$USERNAME/.config/bspwm-dotfiles && python3 Builder/install.py"

    # 5.14 Настройка .xinitrc для bspwm
    echo "exec bspwm" > /home/"$USERNAME"/.xinitrc
    chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.xinitrc

EOF_CHROOT

echo "--- Установка завершена ---"
echo "Теперь вы можете перезагрузить систему: reboot"
echo "После перезагрузки войдите как выбранный пользователь и запустите startx"


#Настройка WiFi
#iwctl
#device list # Найдите ваше устройство Wi-Fi (например, wlan0)
#station <ваше_устройство> scan
#station <ваше_устройство> get-networks
#station <ваше_устройство> connect <SSID_вашей_сети>
# Введите пароль
#exit
