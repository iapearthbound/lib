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


#--------------------------------------------------------------------------------------------------------------------------------
# currently there is no option to create an image without root
# you can compile a kernel but you can complete the whole process
# if you find a way, please submit code corrections. Thanks.
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$UID" -ne 0 ]
	then echo "Please run as root"
	exit
fi


# We'll use this tittle on all menus
backtitle="Armbian building script, http://www.armbian.com | Author: Igor Pecovnik"

# Install menu support
if [ $(dpkg-query -W -f='${Status}' whiptail 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
apt-get install -qq -y whiptail > /dev/null 2>&1
fi 

#--------------------------------------------------------------------------------------------------------------------------------
# Choose destination - creating board list from file configuration.sh
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$BOARD" == "" ]; then
	IFS=";"
	MYARRAY=($(cat $SRC/lib/configuration.sh | awk '/\)#enabled/ || /#des/' | sed 's/)#enabled//g' | sed 's/#description //g' | sed ':a;N;$!ba;s/\n/;/g'))
	MYPARAMS=( --title "Choose a board" --backtitle $backtitle --menu "\n Supported:" 28 62 18 )
	i=0
	j=1
	while [[ $i -lt ${#MYARRAY[@]} ]]
	do
        MYPARAMS+=( "${MYARRAY[$i]}" "         ${MYARRAY[$j]}" )
        i=$[$i+2];j=$[$j+2]
	done
	whiptail "${MYPARAMS[@]}" 2>results  
	BOARD=$(<results)
	rm results
	unset MYARRAY
fi
# exit the script on cancel
if [ "$BOARD" == "" ]; then echo "ERROR: You have to choose one board"; exit; fi


#--------------------------------------------------------------------------------------------------------------------------------
# Choose for which distribution you want to compile
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$KERNEL_ONLY" != "yes" ]; then
if [ "$RELEASE" == "" ]; then
	IFS=";"
	declare -a MYARRAY=('wheezy' 'Debian 7 Wheezy | oldstable' 'jessie' 'Debian 8 Jessie | stable' 'trusty' 'Ubuntu Trusty Tahr 14.04.x LTS');
	MYPARAMS=( --title "Choose a distribution" --backtitle $backtitle --menu "\n Root file system:" 13 60 3 )
	i=0
	j=1	
	while [[ $i -lt ${#MYARRAY[@]} ]]
	do
        MYPARAMS+=( "${MYARRAY[$i]}" "         ${MYARRAY[$j]}" )
        i=$[$i+2]
		j=$[$j+2]
	done
	whiptail "${MYPARAMS[@]}" 2>results  
	RELEASE=$(<results)
	rm results
	unset MYARRAY
fi
# exit the script on cancel
if [ "$RELEASE" == "" ]; then echo "ERROR: You have to choose one distribution"; exit; fi


#--------------------------------------------------------------------------------------------------------------------------------
# Choose to build a desktop
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$BUILD_DESKTOP" == "" ]; then
	IFS=";"
	declare -a MYARRAY=('No' 'Command line interface' 'Yes' 'XFCE graphical interface');
	MYPARAMS=( --title "Install desktop with HW acceleration on some boards" --backtitle $backtitle --menu "" 11 60 2 )
	i=0
	j=1
	while [[ $i -lt ${#MYARRAY[@]} ]]
	do
        MYPARAMS+=( "${MYARRAY[$i]}" "         ${MYARRAY[$j]}" )
        i=$[$i+2]
		j=$[$j+2]
	done
	whiptail "${MYPARAMS[@]}" 2>results  
	BUILD_DESKTOP=$(<results)
	BUILD_DESKTOP=${BUILD_DESKTOP,,}
	rm results
	unset MYARRAY
fi
# exit the script on cancel
if [ "$BUILD_DESKTOP" == "" ]; then echo "ERROR: You need to choose"; exit; fi

fi


#--------------------------------------------------------------------------------------------------------------------------------
# Choose for which branch you want to compile
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$BRANCH" == "" ]; then
	IFS=";"
	declare -a MYARRAY=('default' '3.4.x - 3.14.x most supported' 'next' 'Vanilla / mainline latest stable');
	# Exceptions
	if [[ $BOARD == "cubox-i" || $BOARD == "udoo-neo" ]]; then declare -a MYARRAY=('default' '3.4.x - 3.14.x most supported'); fi
	MYPARAMS=( --title "Choose a branch" --backtitle $backtitle --menu "\n Kernel:" 11 60 2 )
	i=0
	j=1
	while [[ $i -lt ${#MYARRAY[@]} ]]
	do
        MYPARAMS+=( "${MYARRAY[$i]}" "         ${MYARRAY[$j]}" )
        i=$[$i+2]
		j=$[$j+2]
	done
	whiptail "${MYPARAMS[@]}" 2>results  
	BRANCH=$(<results)
	rm results
	unset MYARRAY
fi

# exit the script on cancel
if [ "$BRANCH" == "" ]; then echo "ERROR: You have to choose one branch"; exit; fi

# don't compile external modules on mainline
if [ "$BRANCH" == "next" ]; then EXTERNAL="no"; fi

# back to normal
unset IFS

# default console if not set
if [ "$CONSOLE_CHAR" == "" ]; then CONSOLE_CHAR="UTF-8"; fi

#--------------------------------------------------------------------------------------------------------------------------------
# check which distro we are building
#--------------------------------------------------------------------------------------------------------------------------------
if [[ "$RELEASE" == "precise" || "$RELEASE" == "trusty" ]]; then
	DISTRIBUTION="Ubuntu"
	else
	DISTRIBUTION="Debian"
fi


#--------------------------------------------------------------------------------------------------------------------------------
# Let's fix hostname to the board
#
HOST="$BOARD"


#--------------------------------------------------------------------------------------------------------------------------------
# Load libraries
#--------------------------------------------------------------------------------------------------------------------------------
source $SRC/lib/general.sh					# General functions
source $SRC/lib/configuration.sh			# Board configuration
source $SRC/lib/deboostrap.sh 				# System specific install
source $SRC/lib/distributions.sh 			# System specific install
source $SRC/lib/patching.sh 				# Source patching
source $SRC/lib/boards.sh 					# Board specific install
source $SRC/lib/desktop.sh 					# Desktop specific install
source $SRC/lib/common.sh 					# Functions 

if [ "$SOURCE_COMPILE" != "yes" ]; then
	choosing_kernel
	if [ "$CHOOSEN_KERNEL" == "" ]; then echo "ERROR: You have to choose one kernel"; exit; fi
fi

# needed if process failed in the middle
umount_image

#--------------------------------------------------------------------------------------------------------------------------------
# The name of the job
#--------------------------------------------------------------------------------------------------------------------------------
VERSION="Armbian $REVISION ${BOARD^} $DISTRIBUTION $RELEASE $BRANCH"
 
#--------------------------------------------------------------------------------------------------------------------------------
# let's start with fresh screen
#--------------------------------------------------------------------------------------------------------------------------------
clear

# not yet ready
#cleaning "$CLEAN_LEVEL"

display_alert "Dependencies check" "@host" "info"

#--------------------------------------------------------------------------------------------------------------------------------
# optimize build time with 100% CPU usage
#--------------------------------------------------------------------------------------------------------------------------------
CPUS=$(grep -c 'processor' /proc/cpuinfo)
if [ "$USEALLCORES" = "yes" ]; then
CTHREADS="-j$(($CPUS + $CPUS/2))";
else
CTHREADS="-j${CPUS}";
fi


#--------------------------------------------------------------------------------------------------------------------------------
# to display build time at the end
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$KERNEL_ONLY" == "yes" ]; then
		display_alert "Compiling kernel" "$BOARD" "info"
	else
		display_alert "Building" "$VERSION" "info"
fi

#--------------------------------------------------------------------------------------------------------------------------------
# download packages for host
#--------------------------------------------------------------------------------------------------------------------------------
download_host_packages

#--------------------------------------------------------------------------------------------------------------------------------
# sync clock
#--------------------------------------------------------------------------------------------------------------------------------


if [ "$SYNC_CLOCK" != "no" ]; then
	display_alert "Synching clock" "host" "info"
	ntpdate -s time.ijs.si
fi
start=`date +%s`

#--------------------------------------------------------------------------------------------------------------------------------
# fetch_from_github [repository, sub directory]
#--------------------------------------------------------------------------------------------------------------------------------
mkdir -p $DEST -p $SOURCES

if [ "$FORCE_CHECKOUT" = "yes" ]; then
	FORCE="-f"
	else
	FORCE=""
fi
display_alert "source downloading" "@host" "info"

fetch_from_github "$BOOTLOADER" "$BOOTSOURCE" "$BOOTDEFAULT"
fetch_from_github "$LINUXKERNEL" "$LINUXSOURCE" "$LINUXDEFAULT"
if [[ -n "$MISC1" ]]; then fetch_from_github "$MISC1" "$MISC1_DIR"; fi
if [[ -n "$MISC2" ]]; then fetch_from_github "$MISC2" "$MISC2_DIR"; fi
if [[ -n "$MISC3" ]]; then fetch_from_github "$MISC3" "$MISC3_DIR"; fi
if [[ -n "$MISC4" ]]; then fetch_from_github "$MISC4" "$MISC4_DIR" "master"; fi
if [[ -n "$MISC5" ]]; then fetch_from_github "$MISC5" "$MISC5_DIR"; fi

# compile sunxi tools
if [[ $LINUXCONFIG == *sun* ]]; then 
compile_sunxi_tools
fi

# clean open things if scripts stops in the middle
umount_image

# Patching sources
patching_sources


# Compile kernel only if not exits in cache. kernel clean override
if [[ $BRANCH == "next" ]] ; then KERNEL_BRACH="-next"; UBOOT_BRACH="-next"; else KERNEL_BRACH=""; UBOOT_BRACH=""; fi 

CHOOSEN_UBOOT="linux-u-boot"$UBOOT_BRACH"-"$BOARD"_"$REVISION"_armhf"

if [[ $KERNEL_CLEAN == "no" ]] ; then
	# check if proper kernel deb exists
	TMP=linux-image"$KERNEL_BRACH"-"$CONFIG_LOCALVERSION$LINUXFAMILY"_"$REVISION"_armhf.deb
	if [ -f "$DEST/debs/$TMP" ]; then
		CHOOSEN_KERNEL=$TMP
		#echo $TMP
		SOURCE_COMPILE="no"
	fi
	# check if proper u-boot deb exists
	if [ ! -f "$DEST/debs/$CHOOSEN_UBOOT"".deb" ]; then
		compile_uboot
	fi
	
fi



#--------------------------------------------------------------------------------------------------------------------------------
# Compile source or choose already packed kernel
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$SOURCE_COMPILE" = "yes" ]; then

	# Compile boot loader
	compile_uboot

	# compile kernel and create archives
	compile_kernel
	if [ "$KERNEL_ONLY" == "yes" ]; then
		display_alert "Kernel building done" "@host" "info"
		display_alert "Target directory" "$DEST/debs/" "info"
		display_alert "File name: $CHOOSEN_KERNEL" "$VER" "info"
	fi
	
fi

if [ "$KERNEL_ONLY" != "yes" ]; then

#--------------------------------------------------------------------------------------------------------------------------------
# create or use prepared root file-system
#--------------------------------------------------------------------------------------------------------------------------------
custom_debootstrap


#--------------------------------------------------------------------------------------------------------------------------------
# add kernel to the image
#--------------------------------------------------------------------------------------------------------------------------------
install_kernel


#--------------------------------------------------------------------------------------------------------------------------------
# install board specific applications
#--------------------------------------------------------------------------------------------------------------------------------
install_system_specific
install_board_specific


#--------------------------------------------------------------------------------------------------------------------------------
# install desktop
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$BUILD_DESKTOP" = "yes" ]; then
install_desktop
fi


#--------------------------------------------------------------------------------------------------------------------------------
# install external applications
#--------------------------------------------------------------------------------------------------------------------------------
if [ "$EXTERNAL" = "yes" ]; then
install_external_applications
fi


#--------------------------------------------------------------------------------------------------------------------------------
# closing image
#--------------------------------------------------------------------------------------------------------------------------------
#read
closing_image

fi

end=`date +%s`
runtime=$(((end-start)/60))
umount $SOURCES/$LINUXSOURCE/drivers/video/fbtft >/dev/null 2>&1
display_alert "Runtime" "$runtime min" "info"
