#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/igorpecovnik/lib
#


# vaid options for automatic building
#
# build 0 = don't build
# build 1 = old kernel
# build 2 = next kernel
# build 3 = both kernels


#--------------------------------------------------------------------------------------------------------------------------------
# common options
#--------------------------------------------------------------------------------------------------------------------------------

REVISION="4.5" 											# all boards have same revision
SDSIZE="4000" 											# SD image size in MB
TZDATA=`cat /etc/timezone`								# Timezone for target is taken from host or defined here.
USEALLCORES="yes"                           			# Use all CPU cores for compiling
SYSTEMD="yes"											# Enable or disable systemd on Jessie. 
OFFSET="1" 												# Bootloader space in MB (1 x 2048 = default)
BOOTSIZE="0" 											# Mb size of boot partition
UBOOTTAG="v2015.07"										# U-boot TAG
BOOTLOADER="git://git.denx.de/u-boot.git"				# mainline u-boot sources
BOOTSOURCE="u-boot"										# mainline u-boot local directory
BOOTDEFAULT="master" 									# default branch that git checkout works properly
LINUXDEFAULT="HEAD" 									# default branch that git checkout works properly
MISC1="https://github.com/linux-sunxi/sunxi-tools.git"	# Allwinner fex compiler / decompiler	
MISC1_DIR="sunxi-tools"									# local directory
MISC2=""												# Reserved
MISC2_DIR=""											# local directory
MISC3="https://github.com/dz0ny/rt8192cu"				# Realtek drivers
MISC3_DIR="rt8192cu"									# local directory
MISC4="https://github.com/notro/fbtft"					# Small TFT display driver
MISC4_DIR="fbtft-drivers"								# local directory
MISC5="https://github.com/hglm/a10disp/"				# Display changer for Allwinner
MISC5_DIR="sunxi-display-changer"						# local directory

#--------------------------------------------------------------------------------------------------------------------------------
# If KERNELTAG is not defined, let's compile latest stable. Vanilla kernel only
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$KERNELTAG" == "" ]; then
KERNELTAG="v"`wget -qO-  https://www.kernel.org/finger_banner | grep "The latest stable" | awk '{print $NF}'`
fi

#--------------------------------------------------------------------------------------------------------------------------------
# common for legacy allwinner kernel-source
#--------------------------------------------------------------------------------------------------------------------------------

# linux-sunxi
LINUXKERNEL="https://github.com/iapearthbound/linux-sunxi.git"
LINUXSOURCE="linux-sunxi"
LINUXFAMILY="sun7i"
LINUXCONFIG="linux-sun7i"

CPUMIN="480000"
CPUMAX="1010000"


#--------------------------------------------------------------------------------------------------------------------------------
# choose configuration
#--------------------------------------------------------------------------------------------------------------------------------
case $BOARD in


pcduino3nano)#enabled
#description A20 dual core 1Gb SoC
#build 3
#--------------------------------------------------------------------------------------------------------------------------------
# pcduino3nano
#--------------------------------------------------------------------------------------------------------------------------------
BOOTCONFIG="Linksprite_pcDuino3_Nano_defconfig"
MODULES="hci_uart gpio_sunxi rfcomm hidp sunxi-ir bonding spi_sun7i"
MODULES_NEXT="bonding"
;;



*) echo "Board configuration not found"
exit
;;
esac


#--------------------------------------------------------------------------------------------------------------------------------
# Vanilla Linux, second option, ...
#--------------------------------------------------------------------------------------------------------------------------------
if [[ $BRANCH == *next* ]];then
	# All next compilations are using mainline u-boot & kernel
	LINUXKERNEL="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
	LINUXSOURCE="linux-mainline"
	LINUXCONFIG="linux-sunxi-next"
	LINUXDEFAULT="master"
	LINUXFAMILY="sunxi"
	FIRMWARE=""
fi
