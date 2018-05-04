all:
	echo Running make_sfr.sh
	script=./make_sfr.sh
	if [ -e "$(CONFIG)/make_sfr.sh" ] ; then \
	   script=$(CONFIG)/make_sfr.sh ; \
	fi ; \
	sudo DEBUG_SET_X=$(DEBUG_SET_X) config=$(CONFIG) $$script $(SOURCE_IMAGE) $(SELSIGN_TOOLS) $(PRIV_KEY) $(PUB_KEY)
	sudo chown -R $$(stat -c "%u" .) *
	if [ ! -e pflash ] ; then cp bios.bin pflash ; fi

clean:
	rm -rf efi-test.img efi_vol up-initrd.orig up-initrd.uncompressed.orig pflash grub-sfr.cfg.p7b initrd-extras pflash config_*/grub-sfr.cfg.p7b config_*/grub-final.cfg.p7b in upgrade.tar.bz2 upgrade.tar

