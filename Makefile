# 
# initrd.git/Makefile
#

TOPDIR = $(shell pwd)

include $(TOPDIR)/../toolchain/vars.mk

TARGET = arm-crux-linux-gnueabi
DEVICE = versatile

WORK = $(TOPDIR)/work
CLFS = $(TOPDIR)/../toolchain/clfs
CROSSTOOLS = $(TOPDIR)/../toolchain/crosstools

BUSYBOX_VERSION  = 1.18.4
BUSYBOX_SOURCE   = http://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

DIALOG_VERSION = 1.1-20100119
DIALOG_SOURCE = ftp://dickey.his.com/dialog/dialog-$(DIALOG_VERSION).tgz

.PHONY: all check-root busybox dialog initrd clean distclean

all: initrd

clean: busybox-clean dialog-clean initrd-clean

dist-clean: busybox-distclean dialog-distclean initrd-distclean

check-root:
	@if [ "$$UID" != "0" ]; then \
		echo "You need to be root to do this."; \
		echo "Now you should run 'make initrd' as root to finish compilation or 'sudo make initrd'."; \
		exit 1; \
	fi

$(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2:
	wget -P $(WORK) -c $(BUSYBOX_SOURCE)

$(WORK)/busybox-$(BUSYBOX_VERSION): $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2 $(TOPDIR)/busybox-$(BUSYBOX_VERSION).config
	tar -C $(WORK) -xvjf $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2
	cp -v $(TOPDIR)/busybox-$(BUSYBOX_VERSION).config $(WORK)/busybox-$(BUSYBOX_VERSION)/.config
	touch $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2

$(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox: $(WORK)/busybox-$(BUSYBOX_VERSION)
	export PATH=$(CROSSTOOLS)/bin:$$PATH &&  \
	export LD_LIBRARY_PATH=$(CROSSTOOLS)/lib:$$LD_LIBRARY_PATH && \
	make -C $(WORK)/busybox-$(BUSYBOX_VERSION) ARCH=arm CROSS_COMPILE=$(TARGET)- install && \
	install -D -m 0755 $(WORK)/busybox-$(BUSYBOX_VERSION)/examples/udhcp/simple.script $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/usr/share/udhcpc/default.script && \
	$(TARGET)-strip $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox && \
	touch $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox

busybox: $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox

busybox-clean:
	rm -vrf $(WORK)/busybox-$(BUSYBOX_VERSION)

busybox-distclean:
	rm -vf $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2

$(WORK)/dialog-$(DIALOG_VERSION).tgz:
	wget -P $(WORK) -c $(DIALOG_SOURCE)

$(WORK)/dialog-$(DIALOG_VERSION): $(WORK)/dialog-$(DIALOG_VERSION).tgz
	tar -C $(WORK) -xvzf $(WORK)/dialog-$(DIALOG_VERSION).tgz
	touch $(WORK)/dialog-$(DIALOG_VERSION)

$(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog: $(WORK)/dialog-$(DIALOG_VERSION)
	export PATH=$(CROSSTOOLS)/bin:$$PATH && \
	export LD_LIBRARY_PATH=$(CROSSTOOLS)/lib:$$LD_LIBRARY_PATH && \
	cd $(WORK)/dialog-$(DIALOG_VERSION) && \
		./configure --build=$(BUILD) --host=$(TARGET) --prefix=/usr --with-ncursesw && \
		find -type f -name 'makefile' \
		-exec sed -e "s|-I/usr|-I$(CLFS)/usr|g" -e "s|-L/usr|-L$(CLFS)/usr|g" -i {} \; && \
		make CC="$(TARGET)-gcc -static" && \
		make DESTDIR=$(WORK)/dialog-$(DIALOG_VERSION)/_install install && \
		$(TARGET)-strip $(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog && \
		touch $(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog

dialog: $(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog

dialog-clean:
	rm -vrf $(WORK)/dialog-$(DIALOG_VERSION)

dialog-distclean:
	rm -rf $(WORK)/dialog-$(DIALOG_VERSION).tgz

$(WORK)/mnt:
	mkdir -p $(WORK)/mnt

$(WORK)/initrd.gz: check-root busybox dialog $(WORK)/mnt $(TOPDIR)/filesystem $(TOPDIR)/mkinitrd.sh
	sh mkinitrd.sh --name=$(WORK)/initrd.gz --size=4096
	cd $(WORK) && gunzip -v initrd.gz
	mount -v -t ext2 -o loop,rw $(WORK)/initrd $(WORK)/mnt
	cp -dRv $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/* $(WORK)/mnt
	install -v -m 0755 $(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog $(WORK)/mnt/usr/bin
	cp -dRv $(CLFS)/lib/libnss_{files*,dns*} $(CLFS)/lib/libresolv* $(WORK)/mnt/lib
	install -d  $(WORK)/mnt/usr/share/terminfo
	cp -dRv $(CLFS)/usr/share/terminfo/v $(WORK)/mnt/usr/share/terminfo
	install -v -m 0644 $(TOPDIR)/filesystem/{fstab,inittab,profile,protocols,*.conf} $(WORK)/mnt/etc
	install -v -m 0755 $(TOPDIR)/filesystem/rc $(WORK)/mnt/etc && \
	install -v -m 0755 $(TOPDIR)/filesystem/{setup,crux} $(WORK)/mnt/usr/bin && \
	/sbin/ldconfig -r $(WORK)/mnt
	umount -v $(WORK)/mnt
	cd $(WORK) && gzip -v initrd
	touch $(WORK)/initrd.gz

initrd: $(WORK)/initrd.gz

initrd-clean: check-root
	rm -rf initrd.gz

initrd-distclean: initrd-clean

# End of file
