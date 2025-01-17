#! /bin/sh
# script runs after debian installer has done its thing

#Fix dmraid
if test -x /sbin/dmraid
then
  for i in `dmraid -c -s`
    do sed -ir "s#(/dev/mapper/${i})p([0-9]+\s)#\1\2#" /target/etc/fstab
  done
fi

chroot /target adduser --gecos "" --disabled-password steam
chroot /target usermod -a -G desktop,audio,dip,video,plugdev,netdev,bluetooth,pulse-access steam
chroot /target usermod -a -G pulse-access desktop
chroot /target /usr/lib/x86_64-linux-gnu/lightdm/lightdm-set-defaults -a steam
cp -r /cdrom/recovery /target/boot > /target/var/log/post_install.log
mv /target/boot/recovery/live /target/boot/recovery/live-hd
chroot /target date > /target/etc/skel/.imageversion
cp /target/etc/skel/.imageversion /target/home/steam/.imageversion

#
# Add post-logon configuration script
#
cat - > /target/usr/bin/post_logon.sh << 'EOF'
#! /bin/bash
if [[ "$UID" -ne "0" ]]
then
  #
  # Wait up to 10 seconds and see if we have a connection. If not, pop the network dialog
  #
  nm-online -t 10 -q
  if [ "$?" -ne "0" ]; then
    while true;
    do
      zenity --info --title="SteamOS Install" --text="SteamOS cannot connect to the internet. An internet connection is required to continue installation. If you have a wireless network, configure it now."
      nm-connection-editor --type=802-11-wireless --show
      nm-online -t 30
      if [ "$?" -eq "0" ]; then 
        break
      fi
      echo "Still waiting for internet connection..."
    done
  fi
  # dummy file to skip the Steam Install Agreement dialog
  touch ~/.steam/steam_install_agreement.txt
  # pass -exitsteam so steam doesn't actually run after bootstrapping
  steam -exitsteam
  rm ~/.steam/starting
  cp ~/.local/share/Steam/steam_install_agreement.txt ~/.steam/steam_install_agreement.txt
  sudo /usr/bin/post_logon.sh
  exit
fi

# Configure ufw firewall
ufw enable
# Allow ssh, but block brute force attacks
ufw limit ssh/tcp

# Allow in home streaming
ufw allow 27036
ufw allow 27037/tcp
ufw allow 27031/udp

# Disallow root login on ssh
sed -i "s/PermitRootLogin\ yes/PermitRootLogin\ no/" /etc/ssh/sshd_config

# Add the xbmc/kodi repo key
wget -O - http://mirrors.xbmc.org/apt/steamos/steam@xbmc.org.gpg.key | sudo apt-key add -

/usr/lib/x86_64-linux-gnu/lightdm/lightdm-set-defaults -a steam -s steamos
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User1000 org.freedesktop.Accounts.User.SetXSession string:gnome
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User1001 org.freedesktop.Accounts.User.SetXSession string:steamos
(for i in `dkms status | cut -d, -f1-2 | tr , / | tr -d ' '`; do sudo dkms remove $i --all; done) | zenity --progress --no-cancel --pulsate --auto-close --text="Configuring Kernel Modules" --title="SteamOS Installation"
plymouth-set-default-theme -R steamos
update-grub
grub-set-default 0
# boot into recovery partition on the next boot
grub-reboot "Capture System Partition"
passwd --delete desktop
rm /etc/sudoers.d/post_logon
rm /usr/bin/post_logon.sh && reboot
rm /home/steam/.config/autostart/post_logon.desktop
EOF
chmod +x /target/usr/bin/post_logon.sh

#
# Enable anyone to sudo the post logon script
#
echo ALL ALL=NOPASSWD: /usr/bin/post_logon.sh > /target/etc/sudoers.d/post_logon

#
# Set post logon to run at the first logon
#
cat - > /target/home/steam/.config/autostart/post_logon.desktop << 'EOF'
[Desktop Entry]
Type=Application
Exec=/usr/bin/post_logon.sh
X-GNOME-Autostart-enabled=true
Name=postlogon
EOF

#
# Run aticonfig if an AMD card is present
#
if [ -n "$(lspci|grep VGA|grep -i 'AMD\|ATI')" ]; then
	if [ ! -n "$(lspci|grep VGA|grep NVIDIA)" ]; then
		chroot /target update-alternatives --set glx /usr/lib/fglrx
	fi
fi

#
# Disable mouse acceleration
#
cat - > /target/etc/X11/xorg.conf.d/50-mouse-acceleration.conf << 'EOF'
Section "InputClass"
	Identifier "My Mouse"
	MatchIsPointer "yes"
	Option "AccelerationProfile" "-1"
	Option "AccelerationScheme" "none"
EndSection
EOF

#
# Add firewall shortcut to desktop's desktop
#
#
cat - > /target/home/desktop/Desktop/gufw.desktop << 'EOF'
#!/usr/bin/env xdg-open
[Desktop Entry]
Name=Firewall Configuration
Comment=the gufw interface for the ufw firewall
Exec=/usr/bin/gufw
Icon=gufw
Terminal=false
Type=Application
EOF
chmod +x /target/home/desktop/Desktop/gufw.desktop
chroot /target chown desktop:desktop /home/desktop/Desktop/gufw.desktop 

#
# Set set-passwd.sh to run when desktop first logs in
#
#
cat - > /target/home/desktop/.config/autostart/set-passwd.desktop << 'EOF'
#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Exec=/home/desktop/set-passwd.sh
X-GNOME-Autostart-enabled=true
Name=set-passwd
EOF
chmod +x /target/home/desktop/.config/autostart/set-passwd.desktop
chroot /target chown desktop:desktop  /home/desktop/.config/autostart/set-passwd.desktop

#
# Add set-passwd.sh to set the desktop user's password
#
#
cat - > /target/home/desktop/set-passwd.sh << 'EOF'
#!/bin/bash
set -e
gsettings set org.gnome.shell.overrides button-layout :minimize,maximize,close
gnome-terminal -x /bin/bash -c "echo 'Choose a password for the desktop account, this password will be used for connecting through ssh and configuring the firewall.'; echo 'Do keep in mind that this machine is running an ssh server already.'; until passwd; do echo 'Try again'; done ;"
rm ~/.config/autostart/set-passwd.desktop
rm ~/set-passwd.sh
EOF
chmod +x /target/home/desktop/set-passwd.sh
chroot /target chown desktop:desktop /home/desktop/set-passwd.sh

#
# Add the XBMC/Kodi repo
#
cat - > /target/etc/apt/sources.list.d/xbmc.list << 'EOF'
deb http://mirrors.xbmc.org/apt/steamos alchemist main
EOF

#
# Boot splash screen and GRUB configuration
#
if test `/target/bin/grep -A10000 "### BEGIN /etc/grub.d/30_os-prober ###" /target/boot/grub/grub.cfg | /target/bin/grep -B10000 "### END /etc/grub.d/30_os-prober ###" | wc -l` -gt 4; then
ISDUALBOOT=Y
else
ISDUALBOOT=N
fi
cat - > /target/etc/default/grub << EOF
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=saved
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_DISTRIBUTOR=\`lsb_release -i -s 2> /dev/null || echo Debian\`
GRUB_CMDLINE_LINUX=""
GRUB_BACKGROUND=/usr/share/plymouth/themes/steamos/steam.png
GRUB_DISABLE_LINUX_RECOVERY="true"
GRUB_GFXMODE=auto
EOF
if test "${ISDUALBOOT}" = N; then
echo "GRUB_TIMEOUT=0" >> /target/etc/default/grub
echo "GRUB_HIDDEN_TIMEOUT=1" >> /target/etc/default/grub
else
echo "GRUB_TIMEOUT=5" >> /target/etc/default/grub
fi


# Add system partition backup/restore to the boot menu
RECOVERYPARTITION=`mount | grep "/target/boot/recovery " | cut -f1 -d' '`
ROOTPARTITION=`mount | grep "/target " | cut -f1 -d' ' | cut -f3- -d'/'`
SWAPPARTITION=`tail -1 /proc/swaps | cut -f1 -d' '`
ISMDRAID=`echo "${RECOVERYPARTITION} ${ROOTPARTITION} ${SWAPPARTITION}" | grep "md"`
ISLVM=`echo "${RECOVERYPARTITION} ${ROOTPARTITION} ${SWAPPARTITION}" | grep "mapper"`
if test -z "${ISLVM}" && test -z "${ISMDRAID}" && test -n "${RECOVERYPARTITION}" && test -n "${ROOTPARTITION}" && test -n "${SWAPPARTITION}"; then
if test -d /sys/firmware/efi/; then
ISEFI=Y
else
ISEFI=N
fi

# enable splash adn set framebuffer size to 1024x768x24 for non-efi systems
if test "${ISEFI}" = "Y"; then
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"" >> /target/etc/default/grub
else
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash vga=0x0318\"" >> /target/etc/default/grub
fi

cat - >> /target/etc/grub.d/40_custom << EOF
menuentry "Capture System Partition"{
  search --set -f /live-hd/vmlinuz
EOF
if test "${ISEFI}" = "Y"; then
echo "  fakebios" >> /target/etc/grub.d/40_custom
fi
cat - >> /target/etc/grub.d/40_custom << EOF
  linux /live-hd/vmlinuz boot=live config  noswap edd=on nomodeset noprompt locales="en_US.UTF-8" keyboard-layouts=NONE ocs_prerun="mount ${RECOVERYPARTITION} /home/partimag" ocs_live_run="ocs-sr -q2 -j2 -z1p -i 2000 -sc -p true saveparts steambox ${ROOTPARTITION}" ocs_live_extra_param="" ocs_live_batch=no vga=788 ip=frommedia   live-media-path=/live-hd bootfrom=${SWAPPARTITION} toram=filesystem.squashfs i915.blacklist=yes radeonhd.blacklist=yes nouveau.blacklist=yes vmwgfx.enable_fbdev=no
  initrd /live-hd/initrd.img
}
menuentry "Restore System Partition"{
  search --set -f /live-hd/vmlinuz
EOF
if test "${ISEFI}" = "Y"; then
echo "  fakebios" >> /target/etc/grub.d/40_custom
fi
cat - >> /target/etc/grub.d/40_custom << EOF
  linux /live-hd/vmlinuz boot=live config  noswap edd=on nomodeset noprompt locales="en_US.UTF-8" keyboard-layouts=NONE ocs_prerun="mount ${RECOVERYPARTITION} /home/partimag" ocs_live_run="ocs-sr -e1 auto -e2 -r -j2 -k -p reboot restoreparts steambox ${ROOTPARTITION}" ocs_live_extra_param="" ocs_live_batch=no vga=788 ip=frommedia   live-media-path=/live-hd bootfrom=${SWAPPARTITION} toram=filesystem.squashfs i915.blacklist=yes radeonhd.blacklist=yes nouveau.blacklist=yes vmwgfx.enable_fbdev=no
  initrd /live-hd/initrd.img
}
menuentry "Clonezilla live"{
  search --set -f /live-hd/vmlinuz
EOF
if test "${ISEFI}" = "Y"; then
echo "  fakebios" >> /target/etc/grub.d/40_custom
fi
cat - >> /target/etc/grub.d/40_custom << EOF
  linux /live-hd/vmlinuz boot=live config  noswap edd=on nomodeset noprompt locales="en_US.UTF-8" keyboard-layouts=NONE ocs_prerun="mount ${RECOVERYPARTITION} /home/partimag" ocs_live_run="ocs-live-general" ocs_live_extra_param="" ocs_live_batch=no vga=788 ip=frommedia  nosplash  live-media-path=/live-hd bootfrom=${SWAPPARTITION} toram=filesystem.squashfs i915.blacklist=yes radeonhd.blacklist=yes nouveau.blacklist=yes vmwgfx.enable_fbdev=no
  initrd /live-hd/initrd.img
}
EOF
elif test -n "${ISMDRAID}"; then
echo "One or more of /, /boot/recovery, or swap is on mdraid. Disabling recovery partition support"
elif test -n "${ISLVM}"; then
echo "One or more of /, /boot/recovery, or swap is on LVM. Disabling recovery partition support"
else
echo "Missing one of /, /boot/recovery, or swap. Disabling recovery partition support"
fi
