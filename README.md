# steamos-installer

 VaporOS - a modified version of the Stephenson's Rocket SteamOS installer, with a number of modifications.
 
# Improvements

- The current SteamOS iso installs SteamOS patch 145, VaporOS installs SteamOS patch 147.
- VaporOS has a firewall installed by default, which can be easily configured from the desktop.
- VaporOS asks you to set a password for the desktop user when you open the desktop for the first time.
- VaporOS has trim support.
- VaporOS offers a better out of the box desktop experience. Things like a text editor, an archive manager and Gnome Tweak Tools are installed by default.
- VaporOS has an ssh server installed by default.
- VaporOS installs many tools to improve the command line experience. This includes bash completion, iotop, htop, mesa-utils, pastebinit, git and lsof. 
- VaporOS has no mouse acceleration.

For a more detailed list of added package, take a look at the file changes.txt.

# Planned improvements

- Support for Legacy AMD 

# How to install?

ISO's for the latest releases are always available on http://trashcan-gaming.nl/

Otherwise, clone this repo, and run `./gen.sh`.

## Installing from a DVD

Just burn the ISO to a blank DVD from your favourite tool, and boot it.

## Installing from USB (Mac)

Open a Terminal window from the Utilities section of Applications.

Type `diskutil list` to get a list of devices - one of them will be your USB stick (e.g. `/dev/disk2`). Follow the Linux instructions below, with this `/dev/rdiskX` entry instead of `/dev/sdX`

## Installing from USB (Linux)

Plug in the USB stick and run `dmesg`; look for a line similar to this:

    [377039.485179] sd 7:0:0:0: [sdc] Attached SCSI removable disk

In this case, `sdc` is the device name for the USB stick you just inserted. Now we put the installer on the stick, as root (e.g. use `sudo`) run 

    dd bs=1M if=/path/to/vaporosX.iso of=/dev/sdX 
    
sdX should be the USB stick device from the information you received from `dmesg`. Be sure to use sdX, not sdX1 or sdX2. Then boot into the stick.

## Installing from USB (Windows)

Download [Win32 Disk Imager](http://sourceforge.net/projects/win32diskimager/) and use it to copy the .iso to your USB stick (1GB minimum size).

## Once the installer is up...

Pick the "Automatic Install" option to wipe the first hard disk in your system and install SteamOS to it.

For more sophisticated booting - e.g. dual-boot or custom partition sizes - select the "Expert" option. Use of this mode is documented in the support video [here](YT).

Beyond that, just follow Valve's instructions from [their site](http://store.steampowered.com/steamos/buildyourown) - Stephenson's Rocket should behave exactly like the real SteamOS, except it works on more systems

# Known issues and workarounds

- Running in Virtualbox is not supported.
- Some games, like Dota 2, currently don't launch. This is not specific to VaporOS.
- On some Nvidia systems, sound over hdmi doesn't work. This is not specific to VaporOS. A fix can be found here: http://steamcommunity.com/groups/steamuniverse/discussions/1/35221584678322281/#c35222218678959581
- aticonfig --initial is not ran by the new AMD drivers. You'll need to run this manually after booting into a black screen.

# Special Thanks

- All contributors to Stephenson's Rocket, Directhex in particular.
- [40-1]PvtBalderick, for help with ideas and testing.
- Dubigrasu, for help with ideas and testing.
- Nate Wardawg, for the name.
- Valve for creating SteamOS in the first place.
