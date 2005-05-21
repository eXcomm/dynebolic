# dyne:II startup scripts
# (C) 2005 Denis "jaromil" Rojo
# GNU GPL License

# nesting utilities

choose_nest() {
    
    # count the nests found in volumes
    NESTS=`cat /boot/volumes|grep nst`
    NESTS_NUM=0

    # extract the interesting array and count it
    for n in ${(f)NESTS}; do
	# volumes syntax: media device mount filesystem
	#        we want: ^^^^^        ^^^^^ ^^^^^^^^^^
	MEDIA="`echo $n|awk '{print $1}'`"
	MNT="`echo $n|awk '{print $3}'`"
	FSYS="`echo $n|awk '{print $4}'`"
	# media mnt fsys
	echo "$MEDIA $MNT $FSYS" >> /boot/nests
	NESTS_NUM=`expr $NESTS_NUM + 1`
    done

    if [ $NESTS_NUM = 0 ]; then
	notice "no nests were found on devices connected"
	
	# look for default dyne:bolic home environment
	SYSDEF="`cat /boot/volumes|grep sys`"
	for d in ${(f)SYSDEF}; do # cycle thru the systems found
	    MNT="`echo $d|awk '{print $3}'`" # get the mountpoint

	    # accept dyne subdir or root
	    if [ -x ${MNT}/dyne ]; then MNT=${MNT}/dyne; fi

	    if [ -r ${MNT}/home.tgz ]; then # check if home.tgz is in there
		# if yes:
		# go for it, we assume also var.tgz is there
		notice "home and settings will be lost at reboot"
	        notice "initializing virtual filesystem in memory"
		RAMSIZE=`cat /proc/meminfo |grep MemTotal: |chomp -- 2`
		SHMSIZE=`expr $RAMSIZE / 1024 / 4`
		act "RAM detected: `expr $RAMSIZE / 1024` Mb"
		act "VFS size: $SHMSIZE Mb"
		echo "tmpfs /dev/shm tmpfs defaults,size=${SHMSIZE}m 0 0" >> /boot/fstab
		cp -f /boot/fstab /etc
		mount /dev/shm
		
		# creating /var /tmp and /home
		act "populating /var from CD"
		tar xfz ${MNT}/var.tgz -C /dev/shm
		mount -o bind /dev/shm/var /var
		
		act "populating /home from CD"
		tar xfz ${MNT}/home.tgz -C /dev/shm
		mount -o bind /dev/shm/home /home
		
		act "building /tmp"
		mkdir /dev/shm/tmp
		mount -o bind /dev/shm/tmp /tmp
		
		DYNE_NEST_PATH=${MNT}
	    fi

	done

	return
    fi # NESTS_NUM = 0
    
    notice "nests found: $NESTS_NUM =- TODO"
}

activate_nest() {
  # nest is allready mounted in /mnt/nest
  # this script shoud now link the directories
  echo " ... OK";

  # nestclean here:
  # zap old logs
  if [ -r /mnt/nest/var/log/dynebolic.log ]; then
    rm /mnt/nest/var/log/dynebolic.log
  fi
  # wipe out /tmp
  if [ -x /mnt/nest/tmp ]; then
      rm -rf /mnt/nest/tmp/*
  fi
  
  if [ ! -e /mnt/nest/home ]; then
      warning "nest is missing home, skipping"
  else
      if [ ! -e /home ]; then mkdir /home; fi
      mount -o bind /mnt/nest/home /home
  fi
  if [ ! -e /mnt/nest/etc ]; then
      warning "nest is missing etc, skipping"
  else
      if [ ! -e /etc ]; then mkdir /etc; fi
      cp /etc/mtab /mnt/nest/etc/mtab
      mount -o bind /mnt/nest/etc /etc
  fi
  if [ ! -e /mnt/nest/var ]; then
      warning "nest is missing var, skipping"
  else
      if [ ! -e /var ]; then mkdir /var; fi
      mount -o bind /mnt/nest/var /var
  fi
  if [ ! -e /mnt/nest/tmp ]; then
      warning "nest is missing tmp, skipping"
  else
      if [ ! -e /var ]; then mkdir /tmp; fi
      mount -o bind /mnt/nest/tmp /tmp
  fi

}

got_home() {
# $1 = path where to take home.tgz and var.tgz
# this check if a home has been found
# if not, use the home.tgz and var.tgz from the given path


    # do we allready have a home? if yes just return
    # this control let us safely call this function multiple times
    if [ -r /home/.xinitrc ]; then return; fi

    # if there is a dyne subdirectory, then use that
    if [ -x ${1}/dyne ]; then
	VOL=${1}/dyne
    else # scan for files in the path supplied
	VOL=${1}
    fi

    # check if a nest is configured in boot prompt of dynebol.cfg
    CFG_NEST=`get_config nest`
    if [ $CFG_NEST ]; then
	echo -n "[?] use the configured nest in ${CFG_NEST} (Y/n)"
	getkey 5
	if [ $? = 1 ]; then
	    echo " ... SKIPPED"
	else
	    echo " ... OK"
	    if [ ! -r ${CFG_NEST} ]; then
		error "configured nest not present in ${CFG_NEST}"
	    fi
	fi
    fi

    # if there is no configurated nest then scan this device
    if [ -z $NEST ]; then
	if [ -r ${}/dynebol.nst ]; then
	    NEST="${VOL}/dynebol.nst"
	    unset ENCRYPT
	elif [ -r ${VOL}/dynebolE.nst ]; then
	    NEST="${VOL}/dynebolE.nst"
	    ENCRYPT="AES128"
	else unset NEST; fi
    fi

    if [ $NEST ]; then
	echo
	echo
	echo
	echo	
	echo -n "[?] use the dyne:bolic nest in ${NEST} (Y/n)"
	getkey 10
	if [ $? = 1 ]; then
	    echo " ... SKIPPED"
	else
	    echo " ... OK"
	    
        # parses the values in a config file, if present
        # this is needed just to know if the nest is encrypted
	# source "`echo ${NEST}|cut -d. -f1`.cfg"
	    
	    notice "activating dyne:bolic nest in ${NEST}"
	    
	    if [ $ENCRYPT ]; then
		act "encrypted with algo $ENCRYPT"
		cat <<EOF




*******************************************************************************
An $ENCRYPT encrypted nest
has been detected in $DYNEBOL_NST
access is password restricted, please supply your passphrase now

EOF
		for i in 1 2 3; do
		    mount -o loop,encryption=$ENCRYPT ${NEST} /mnt/nest
		    case $? in
			0) notice "valid password entered, activating nest!"
			    sleep 1
			    activate_nest
			    break
			    ;;
			32) error "Invalid password"
			    sleep 2
			    continue
			    ;;
			*) error "mount failed with exitcode $?"
			    sleep 2
			    continue
		    esac
		done
		
	    else # nest is not encrypted
		echo -n "[*] mounting nest over loopback device"
		mount -o loop ${NEST} /mnt/nest
		if [ $? != 0 ]; then
		    error "mount failed with exitcode $?"
		    sleep 2
		else
		  activate_nest
		fi
	    fi
	    
	    if [ "`mount | grep /mnt/nest`" ]; then
		act "nest succesfully mounted"
		DYNE_NEST_PATH=${NEST}
	    fi
	fi
	
    else # there isn't a nest, look for standard home and var
	
	if [ ! -r ${VOL}/home.tgz ]; then return; fi
	if [ ! -r ${VOL}/var.tgz ]; then return; fi
	
    # (from the former rc.vfs)
	notice "initializing virtual filesystem in memory"
	RAMSIZE=`cat /proc/meminfo |grep MemTotal: |chomp -- 2`
	SHMSIZE=`expr $RAMSIZE / 1024 / 4`
	act "RAM detected: `expr $RAMSIZE / 1024` Mb"
	act "VFS size: $SHMSIZE Mb"
	echo "tmpfs /dev/shm tmpfs defaults,size=${SHMSIZE}m 0 0" >> /boot/fstab
	cp -f /boot/fstab /etc
	mount /dev/shm
	
    # creating /var /tmp and /home
	act "populating /var from CD"
	tar xfz ${VOL}/var.tgz -C /dev/shm
	mount -o bind /dev/shm/var /var
	
	act "populating /home from CD"
	tar xfz ${VOL}/home.tgz -C /dev/shm
	mount -o bind /dev/shm/home /home
	
	act "building /tmp"
	mkdir /dev/shm/tmp
	mount -o bind /dev/shm/tmp /tmp

	DYNE_NEST_PATH=${VOL}
    fi

    if [ -r /etc/DYNEBOLIC ]; then
      DYNE_NEST_VER=`cat /etc/DYNEBOLIC`
    fi
}
