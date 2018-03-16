all:
	echo Running make_sfr.sh
	sudo DEBUG_SET_X=$(DEBUG_SET_X) ./make_sfr.sh $(SOURCE_IMAGE)
	sudo chown -R $$(stat -c "%u" .) *

clean:
	rm -rf efi-test.img efi_vol up-initrd.orig pflash grub-sfr.cfg.p7b initrd-extras

