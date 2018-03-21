all:
	echo Running make_sfr.sh
	sudo DEBUG_SET_X=$(DEBUG_SET_X) config=$(CONFIG) ./make_sfr.sh $(SOURCE_IMAGE) $(SELSIGN_TOOLS) $(PRIV_KEY) $(PUB_KEY)
	sudo chown -R $$(stat -c "%u" .) *
	if [ ! -e pflash ] ; then cp bios.bin pflash ; fi

clean:
	rm -rf efi-test.img efi_vol up-initrd.orig pflash grub-sfr.cfg.p7b initrd-extras pflash config_2G_efi/grub-sfr.cfg.p7b config_2G_efi/grub-final.cfg.p7b in config_xd10_efi/grub-sfr.cfg.p7b config_xd10_efi/grub-final.cfg.p7b upgrade.tar.bz2

