#!/bin/bash

if [ "${DEBUG_SET_X}" = 1 ] ; then
    set -x
fi

SOURCE_IMAGE="$1"
SELSIGN_TOOLS="$2"
PRIV_KEY="$3"
PUB_KEY="$4"

if [ -z "${config}" ] ; then
    config=config_2G_efi
fi

if [ -z "${SOURCE_IMAGE}" -o ! -e "${SOURCE_IMAGE}" ] ; then
    echo ERROR: You must specify a valid SOURCE_IMAGE
    exit 1
fi

do_sign=1
if [ -z "${SELSIGN_TOOLS}" ] ; then
    echo WARNING: Turning off key signing for kernel, grub, and initramfs
    do_sign=0
fi

if [ ${do_sign} = 1 ] ; then
    if [ ! -e "${PRIV_KEY}" ] ; then
	ERROR Could not find $PRIV_KEY
	exit 1
    fi
    if [ ! -e "${PUB_KEY}" ] ; then
	ERROR Could not find $PUB_KEY
	exit 1
    fi
fi

step1=${step1=1}
step2=${step2=1}
step3=${step3=1}
step4=${step4=1}

#### Step 1 - Transition install media into a OTA style update
if [ $step1 = 1 ] ; then
    dev=`losetup -f --show ${SOURCE_IMAGE}`
    partprobe ${dev}
    mkdir -p t
    mount ${dev}p2 t
    mount ${dev}p1 t/boot
    rm -rf efi_vol
    mkdir efi_vol
    rsync -a -v t/opt/installer/ efi_vol/installer/
    rsync -a -v t/boot/EFI/ efi_vol/EFI/
    rsync -a -v t/boot/EFI/ efi_vol/EFI/
    cp t/boot/images/bzImage efi_vol/up-bzImage
    cp t/boot/images/bzImage.p7b efi_vol/up-bzImage.p7b
    cp t/boot/images/initrd efi_vol/up-initrd
    cp t/boot/images/initrd.p7b efi_vol/up-initrd.p7b
    rm -rf initrd-extras
    mkdir -p initrd-extras
    (cd t ; tar -cf - usr/lib64/libgpg* usr/lib64/libgcrypt* usr/lib64/liblzma* usr/bin/xargs* lib/systemd/libsystemd* lib64/libsystemd* usr/lib64/liblzo* usr/bin/systemd-detect-virt usr/bin/*btrfs* usr/lib64/*btrfs* usr/bin/find* usr/sbin/mkfs* usr/bin/mkfs* usr/bin/whic* usr/bin/jq usr/lib64/libjq* | tar -C ../initrd-extras -xvf -)
    umount t/boot t
    losetup -d ${dev}
    rmdir t
fi

#### Step 2 - Patch up initrd and grub config
if [ $step2 = 1 ] ; then
    (
	mv efi_vol/up-initrd up-initrd.orig
	rm -rf in 
	mkdir in
	( cd in ; zcat ../up-initrd.orig | cpio -id)
	cp ${config}/install-init in
	chmod 755 in/install-init
	( cd initrd-extras ; tar -cf - * | tar -C ../in -xvf - )
	( cd in ; find . | cpio -o -H newc | gzip -9 > ../efi_vol/up-initrd )

	if [ $do_sign = 1 ] ; then
	    # Sign grub cfg
	    LD_LIBRARY_PATH=${SELSIGN_TOOLS}/../lib ${SELSIGN_TOOLS}/selsign --key ${PRIV_KEY} --cert ${PUB_KEY} ${config}/grub-sfr.cfg

	    if [ -e ${config}/grub-final.cfg ] ; then
		# Sign finall installed grub cfg if exists
		LD_LIBRARY_PATH=${SELSIGN_TOOLS}/../lib ${SELSIGN_TOOLS}/selsign --key ${PRIV_KEY} --cert ${PUB_KEY} ${config}/grub-final.cfg
	    fi

	    # Sign initrd
	    LD_LIBRARY_PATH=${SELSIGN_TOOLS}/../lib ${SELSIGN_TOOLS}/selsign --key ${PRIV_KEY} --cert ${PUB_KEY} efi_vol/up-initrd
	fi

	# Copy grub files
	cp ${config}/grub-sfr.cfg efi_vol/EFI/BOOT/grub.cfg
	if [ -e ${config}/grub-sfr.cfg.p7b ] ; then
	    cp ${config}/grub-sfr.cfg.p7b efi_vol/EFI/BOOT/grub.cfg.p7b
	fi
	if [ -e ${config}/grub-final.cfg ] ; then
	    cp ${config}/grub-final.cfg efi_vol/installer/grub-final.cfg
	    if [ -e ${config}/grub-final.cfg.p7b ] ; then
		cp ${config}/grub-sfr.cfg.p7b efi_vol/installer/grub-final.cfg.p7b
	    fi
	fi
    )
fi

#### Step 3 - Customize installer to repartition or not repartition

if [ $step3 = 1 ] ; then
    (
	instdir=$PWD
	if [ -d ${config}/mods ] ; then
	    cd ${config}/mods
	    for e in `find . -type f -o -type l`; do
		if [ -e $instdir/efi_vol/$e ] ; then
		    mv $instdir/efi_vol/$e $instdir/efi_vol/$e.orig
		fi
		tar -cf - $e | tar -C $instdir/efi_vol -xf -
	    done
	fi
    )
fi

#### Step 4 - trial disk

if [ $step4 = 1 ] ; then
    (
	size=16G
	file=efi-test.img
	rm -f $file
	qemu-img create -f raw $file $size
	chown $(stat -c "%u" $(dirname $file)) $file
	#parted -s $file mklabel gpt
	#parted -s $file mkpart ESP fat32 1MiB 2G
	#parted -s $file set 1 boot on
	parted -s $file mklabel msdos
	parted -s $file mkpart primary fat32 1MiB 2G
	parted -s $file set 1 boot on
	dev=`losetup -f --show $file`
	partprobe $dev
	which partx > /dev/null && partx -d $dev
	which partx > /dev/null && partx -v -a $dev
	mkfs.vfat -I -n OVERCBOOT ${dev}p1
	TMPMNT=`mktemp -d`
	mkdir -p $TMPMNT/mnt
	mount ${dev}p1 $TMPMNT/mnt

	# Copy files
	mkdir -p ${TMPMNT}/mnt/EFI/BOOT
	rsync -a -v efi_vol/ ${TMPMNT}/mnt/ 2> /dev/null

	# Cleanup
	umount ${TMPMNT}/mnt
	rm -rf ${TMPMNT}
	losetup -d $dev
    )
fi
