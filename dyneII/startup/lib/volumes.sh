# dyne:II startup scripts
# (C) 2005 Denis "jaromil" Rojo
# GNU GPL License

source /lib/dyne/utils.sh

add_volume() {
  # $1 = media type (hdisk|floppy|usb|cdrom)
  # $2 = device
  # $3 = mount point
  # $4 = filesystem

  MEDIA=${1}
  DEV=${2}
  MNT=${3}
  FS=${4}

  if [ ! -r /boot/volumes ]; then touch /boot/volumes; fi

  FLAGS=""
  DOCK=dyne
    
  case ${MEDIA} in

      "hdisk")
	  PFX=/vol
	  if [ -x ${PFX}/${MNT}/dyne ]; then
	      if [ -r ${PFX}/${MNT}/${DOCK}/dyne.sys ]; then FLAGS="$FLAGS sys"; fi
	      if [ -r ${PFX}/${MNT}/${DOCK}/dyne.nst ]; then FLAGS="$FLAGS nst"; fi
	      if [ -r ${PFX}/${MNT}/${DOCK}/dyne.cfg ]; then FLAGS="$FLAGS cfg"; fi
              if [ -x ${PFX}/${MNT}/${DOCK}/SDK ];      then FLAGS="$FLAGS sdk"; fi
	  fi
	  echo "${MEDIA} /dev/${DEV} ${PFX}/${MNT} ${FS} ${FLAGS}" >> /boot/volumes
	  # TODO: entry in fstab?
	  ;;


# floppy, usb and cdrom are mounted in /rem
      
      "floppy")
	  PFX=/rem
	  echo "${MEDIA} /dev/${DEV} ${PFX}/${MNT} ${FS}" >> /boot/volumes
	  echo "floppy -fstype=auto,sync :/dev/fd0" >> /boot/auto.removable
	  ;;
      
      "usb")
	  PFX=/rem
	  if [ -x ${PFX}/${MNT}/dyne ]; then
	      if [ -r ${PFX}/${MNT}/dyne/dyne.sys ]; then FLAGS="$FLAGS sys"; fi
	      if [ -r ${PFX}/${MNT}/dyne/dyne.nst ]; then FLAGS="$FLAGS nst"; fi
	      if [ -r ${PFX}/${MNT}/dyne/dyne.cfg ]; then FLAGS="$FLAGS cfg"; fi	      
	  fi
	  echo "${MEDIA} /dev/${DEV} ${PFX}/${MNT} ${FS} ${FLAGS}" >> /boot/volumes
	  echo "${MNT} -fstype=${FS},sync :/dev/${DEV}"  >> /boot/auto.removable
	  ;;
      
      "cdrom"|"dvd")
	  echo "${MEDIA} /dev/${DEV} ${PFX}/${MNT} ${FS} ${FLAGS}" >> /boot/volumes
	  echo "${MNT} -fstype=${FS},ro :/dev/${DEV}" >> /boot/auto.removable
	  ;;
      
      *)
	  error "unknown media type ${MEDIA} for add_volume"
	  return 1
	  ;;
  esac
  
  act "${MEDIA} volume on ${PFX}/${MNT}"
  
  return 0
}


###### CDROM

CD_NUM=0
DVD_NUM=0

SYS_CD_FOUND=false
scan_cdrom() {

# CD filesystem is iso9660 unless we have a DVD (on xbox, for example)
    if [ "`uname -a | grep xbox`" ]; then
	act "xbox dvd filesystem: udf"
	CDFS="udf"
    else
	act "ide cdrom filesystem: auto"
	CDFS="auto"
    fi
    

    # scan for ide devices
    for DEV in `ls /proc/ide/hd* -d | cut -d/ -f4`; do

	# if it's not a cdrom then skip it
	# TODO: verify if DVD has a "dvd" entry for media type
	if  [ `cat /proc/ide/$DEV/media` != cdrom ]; then continue; fi

	if [ "`dmesg|grep '$DEV.*DVD'`" ]; then 
	    MEDIA=dvd
	    DVD_NUM=`expr $DVD_NUM + 1`
	    MNT=dvd${DVD_NUM}
	else
	    MEDIA=cdrom
	    CD_NUM=`expr $CD_NUM + 1`
	    MNT=cd${CD_NUM}
	fi
	
	act "scanning ${DEV} -> ${MNT} (${CDFS})"
	
	mkdir -p /mnt/dynecd

#	if [ ! -x /rem/${MNT} ]; then mkdir /rem/${MNT}; fi	
#	mount -t ${CDFS} -o ro /dev/${DEV} /rem/${MNT} 1>/dev/null 2>/dev/null

	mount -t ${CDFS} -o ro /dev/${DEV} /mnt/dynecd 1>/dev/null 2>/dev/null

	if [ $? != 0 ]; then # device was not mounted

	# media is not found inside, delete dir
	# and add the CD as automount device
	    rm -r /mnt/dynecd
	    add_volume ${MEDIA} ${DEV} ${MNT} ${CDFS}

	elif [ -r /mnt/dynecd/dyne/dyne.sys ]; then # device contains dyne sys
	    
	    FLAGS=sys # check if it has also a config file
	    if [ -r /mnt/dynecd/dyne/dyne.cfg ]; then
		FLAGS="$FLAGS cfg"
	    fi
	    
            # leave it mounted and add it to the list of volumes
	    append_line /boot/volumes "${MEDIA} /dev/${DEV} /mnt/dynecd ${CDFS} ${FLAGS}"
	    
	else # device has a CD inside, not the dyne one

	    # unmount it and add it to automount devices
	    umount /mnt/dynecd
	    rm -r /mnt/dynecd
	    add_volume ${MEDIA} ${DEV} ${MNT} ${CDFS}

	fi
	    	
    done
}


###### HARDDISK

scan_partitions() {
# scans a list of fdisk format partitions
PARTITIONS=${1}

        # cycle thru partitions
        # ${(f)..} splits the result of the expansion to lines. see: man zshexpn
	for PART in ${(f)PARTITIONS}; do

	# setup special flags needed for most common BSD fs
	if [ "`echo $PARTITIONS|grep -iE 'BSD|ufs'`" ]; then
	    MOUNT_FS="-t ufs"
	    MOUNT_OPTS="-o ufstype=44bsd"
	else
	    MOUNT_FS=""
	    MOUNT_OPTS=""
	fi


	    PART_FS="`echo $PART|awk '{print $6}'`"
            PART_DEV="`echo $PART|cut -d' ' -f1`"
	    
	    HD_NUM=`expr $HD_NUM + 1`
	    MNT="/vol/hd${HD_NUM}"
	    
	    if [ ! -x ${MNT} ]; then mkdir -p ${MNT}; fi
	            
            # skip it if already mounted as root (partition install)
            if [ "$ROOT_PART" = "$PART_DEV" ]; then

               act "$PART_FS partition $PART_DEV already mounted as root"
               continue

            fi 
	    
	    act "scanning ${PART_FS} partition ${PART_DEV}"
    
	    mount ${MOUNT_FS} ${MOUNT_OPTS} ${PART_DEV} ${MNT}

	    if [ $? != 0 ]; then
	      error "can't mount ${PART_DEV} : not a valid filesystem"
	      HD_NUM=`expr $HD_NUM - 1`
	      continue
	    fi

	    PART_DEV=`basename $PART_DEV`
	    
	    add_volume hdisk ${PART_DEV} hd${HD_NUM} ${PART_FS}
	    
            # have you got a home there?
	    # deprecated: got_home ${MNT}

	done
	


}


HD_NUM=0
scan_harddisk() {
# $1 = device, without partition number (es: hda)
#  DEV=$1

    ROOT_PART="`get_config root | grep -E 'dev.(hd|sd)'`"

	
    # load all kernel modules for supported filesystems
    # refer to SUPPORTED_FS defined in utils.sh
    # all unused modules will be removed at the end of this function
    act "load modules to scan supported filesystems"
    for m in `iterate $SUPPORTED_FS`; do
	loadmod ${m}
    done

    # scan IDE harddisks
    for DEV in `ls /proc/ide/hd* -d | cut -d/ -f4`; do
	
        # skip if not an harddisk
	if  [ `cat /proc/ide/$DEV/media` != disk ]; then continue; fi

	MOUNT_OPTS=""
	MOUNT_FS=""

	if [ "`uname -a | grep xbox`" ]; then
	    MOUNT_FS="-t fatx"
	    MOUNT_OPTS="-o umask=777"
	fi

	# IDE partitions
	PARTITIONS=`fdisk -l /dev/${DEV} |  \
                    grep -Evi 'swap|extended' | grep '^/dev'`
	scan_partitions ${PARTITIONS}

    done

#    for DEV in `dmesg | grep 'Attached scsi disk' | cut -d' ' -f4`; do
    if ! [ -x /dev/scsi ]; then

      act "no SCSI devices detected"

    else

      for DEV in `find /dev/scsi -name 'disc'`; do
	# TODO: be sure to detect it's an harddisk
	PARTITIONS=`fdisk -l ${DEV} | \
                    grep -Evi 'swap|extended' | grep '^/dev'`
	scan_partitions ${PARTITIONS}
      done

    fi

    # now remove all unused filesystem kernel modules
    act "cleanup unused filesystem modules"
    USEDFS=`mount | awk '{print $5}'`
    for fs in `iterate_backwards $SUPPORTED_FS`; do
	if [ -z "`echo ${USEDFS} | grep ${fs}`" ]; then
		rmmod ${fs}
	fi
    done

}


scan_usbstorage() {

    # if no usb controller is present then just skip
    if [ -z "`cat /proc/pci | grep USB`" ]; then return; fi

# usb controllers are now built into the kernel
# in order to support usb keyboards attached from the very beginning
#    loadmod usb-ohci
#    loadmod usb-uhci
# load usb 2.0 support (removed, now loaded by pcimodules)
#    loadmod ehci-hcd


  # load usb storage driver
    loadmod usb-storage

  # mount the usb device filesystem
    mount -t usbfs none /proc/bus/usb
    
    sync

    if [ -z "`cat /proc/bus/usb/devices | grep usb-storage`" ]; then
	# finish here if there is no usb storage device connected
	add_volume usb sda1 usb vfat
	return

    else

        # load filesystems
	loadmod fat
	loadmod vfat
    
	USB_MNT=0
	for DEV in /dev/sd?1 ; do
	    
	    if [ ! -x /rem/${USB_MNT} ]; then mkdir /rem/${USB_MNT}; fi
	    
        # make first a 'usb' so taschino can find a usb key
	    USB_NUM=`expr $USB_NUM + 1`
	    if [ $USB_NUM = 1 ]; then USB_MNT="usb"
	    else USB_MNT="usb${USB_NUM}"; fi
	    
	    mount ${DEV} /rem/${USB_MNT} -t vfat
	    
	    add_volume usb `basename ${DEV}` ${USB_MNT} vfat
	    
	done
    fi
}



# this function is called by the cdrom detection when a system is found on CD
# it goes thru the harddisks detected and check if they have a system
# match versions and ask user what to do if they are different
# (use cd | hd | update hd)
# setup DYNE_SYS_* variables in order to have the system mounted at the end
# of this script
#
# flowchart attempt:
#
# - check all HD, find system and schedule usage in $DYNE_SYS*
# - check all CD, check system version against all HD, query update
#                 if $DYNE_SYS* is not present, set $DYNE_SYS* to CD
#                 if $DYNE_SYS* is present, ask CD or HD

choose_volumes() {

    # count the harddisk
    HDSYS=`cat /boot/volumes|grep -E 'hdisk.*(sys|sdk)'`
    HDSYS_NUM=0

    for v in ${(f)HDSYS}; do
	# volumes syntax: media device mount filesystem
	#        we want:       ^^^^^^ ^^^^^ ^^ TODO ^^ have fsys displayed at choice
	DEV="`echo $v|awk '{print $2}'`"
	MNT="`echo $v|awk '{print $3}'`"

	# if the /mntpoint/dyne/VERSION is there, source it
	if [ -r ${MNT}/dyne/VERSION ]; then
	    # get versions:
	    # DYNE_SYS_VER
	    # DYNE_INITRD_VER
	    source ${MNT}/dyne/VERSION
	fi

	if [ ! -r /boot/hdsyslist ]; then touch /boot/hdsyslist; fi
	# dev mnt sys_ver init_ver
	echo "$DEV $MNT $DYNE_SYS_VER $DYNE_INITRD_VER" >> /boot/hdsyslist
	HDSYS_NUM=`expr $HDSYS_NUM + 1`
    done
    
    # get the first cdrom
    CDSYS="`cat /boot/volumes|grep -E 'cdrom.*sys'`"
    C=0
    for v in ${(f)CDSYS}; do
	C=`expr $C + 1`

	if [ $C != 1 ]; then
	    warning "multiple system cdroms were detected"
	    warning "using: $v"
	else
	    CD=${v} # get only the first
	fi
    done
    

    if [ $HDSYS_NUM = 0 ]; then # no docks ...

	if [ -z $CD ]; then # no cd
	    
	    error "no device containing the dyne:bolic system was detected"
	    return
	    
	else # cd found
	    
	    DYNE_SYS_MEDIA=cdrom
	    DYNE_SYS_DEV="`echo $CD|awk '{print $2}'`"
	    DYNE_SYS_MNT="`echo $CD|awk '{print $3}'`"
	    return

	fi

    elif [ $HDSYS_NUM = 1 ]; then # ***** ... there is one dock
	
	if [ $CD ]; then # and there is a cdrom

	    MNT="`echo $CD|awk '{print $3}'`"
	    source ${MNT}/dyne/VERSION

	    # check if version differs between cd and hdisk
	    # hdsyslist format: dev mnt sys_ver init_ver
	    HD_SYS_VER="`cat /boot/hdsyslist|awk '{print $3}'`"
	    HD_INIT_VER="`cat /boot/hdsyslist| awk '{print $4}'`"
	    if [ "$DYNE_SYS_VER" != "$HD_SYS_VER" ]; then ask_update=true; fi
	    if [ "$DYNE_INITRD_VER" != "$HD_INIT_VER" ]; then ask_update=true; fi

	    echo; echo; echo; echo; echo;
	    # prompt if upgrading from cd is desired
	    if [ x$ask_update = xtrue ]; then
		notice "the dyne:bolic system on your harddisk is different from the CDROM"
		act "CDROM\t:: sys $DYNE_SYS_VER\t:: init $DYNE_INITRD_VER"
		act "HDISK\t:: sys $HD_SYS_VER\t:: init $HD_INITRD_VER"
		echo "[?] do you want to upgrade the system on your harddisk? (y/n)"
		echo; echo; echo; echo; echo;
		ask_yesno 10 y n
		if [ $? = 1 ]; then
		    notice "upgrading harddisk system version to $DYNE_SYS_VER"
		    act "please wait while transferring files..."
		    echo; echo; echo;	    
		    HD_MNT="`cat /boot/hdsyslist|awk '{print $2}'`"
		    cp -rfv ${MNT}/dyne ${HD_MNT}
		    act "done!"
		    echo; echo; echo; echo; echo;
		else
		    act "Nothing to upgrade."
		fi
	    fi

	    # TODO: choice for harddisk or cdrom
	    notice "mounting the harddisk docked system on $DYNE_SYS_MNT"
	    DYNE_SYS_MEDIA=hdisk
	    DYNE_SYS_DEV="`cat /boot/hdsyslist|awk '{print $1}'`"
	    DYNE_SYS_MNT="`cat /boot/hdsyslist|awk '{print $2}'`"
	    source ${DYNE_SYS_MNT}/dyne/VERSION
	    return

	else # and there is no cdrom

	    notice "mounting the harddisk docked system on $DYNE_SYS_MNT"
	    DYNE_SYS_MEDIA=hdisk
	    DYNE_SYS_DEV="`cat /boot/hdsyslist|awk '{print $1}'`"
	    DYNE_SYS_MNT="`cat /boot/hdsyslist|awk '{print $2}'`"
	    source ${DYNE_SYS_MNT}/dyne/VERSION
	    return
	    
	fi

    else # ... there is more than one dock

	if [ $CD ]; then # and there is a cdrom

	    
	    MNT="`echo $CD|awk '{print $3}'`"
	    source ${MNT}/dyne/VERSION

	    notice "booting from CDROM system version $DYNE_SYS_VER"
	    act "multiple systems have been detected, choose one to upgrade"
	    C=0
	    for i in `cat /boot/hdsyslist`; do
		C=`expr $C + 1`
		DEV=`echo $i| awk '{print $1}'`
		MNT=`echo $i| awk '{print $2}'`
		SYS_VER=`echo $i| awk '{print $3}'`
		echo "$C - $DEV mounted on $MNT\t:: sys $VER"
	    done
	    echo "[?] choose one or wait 10 seconds"
	    ask_choice 10 ${C}
	    if [ $? != -1 ]; then
		HD_MNT="`cat /boot/hdsyslist | awk -v line=$? 'NR==line {print $2}'`"
		act "TODO: here should cp -rfv ${MNT}/dyne ${HD_MNT}"
	    fi
	    
	# dev mnt sys_ver init_ver
	    if [ "$DYNE_SYS_VER" != "`cat /boot/hdsyslist|awk '{print $3}'`" ]; then
		ask_update=true; fi
	    if [ "$DYNE_INITRD_VER" != "`cat /boot/hdsyslist|awk '{print $4}'`" ]; then
		ask_update=true; fi
	    
	    # prompt if upgrading from cd is desired
	    if [ x$ask_update = xtrue ]; then
		# QUAAAA
		ask_yesno
	    fi
	

	else # there is not a cdrom

	    # offer a multiple choice of the boot from /boot/hdsyslist
	    notice "multiple dyne:bolic systems have been detected on your harddisks"
	    act "choose the one you want to run (first is default after 10 seconds):"
	    C=0
            HDSYSLIST=`cat /boot/hdsyslist`
	    for i in ${(f)HDSYSLIST}; do
		C=`expr $C + 1`
		DEV=`echo $i| awk '{print $1}'`
		MNT=`echo $i| awk '{print $2}'`
		SYS_VER=`echo $i| awk '{print $3}'`
		echo "$C - $DEV mounted on $MNT\t:: sys $VER"
	    done

	    echo "TODO"


	fi

    fi
}

# TODO: sys_list che lista tutti i sistemi e fa scegliere con ask_choice
