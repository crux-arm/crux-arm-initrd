# 
# initrd/Makefile
#

TOPDIR = $(shell pwd)

include $(TOPDIR)/../toolchain/vars.mk

TARGET = arm-crux-linux-gnueabihf

WORK = $(TOPDIR)/work
CLFS = $(TOPDIR)/../toolchain/clfs
CROSSTOOLS = $(TOPDIR)/../toolchain/crosstools

BUSYBOX_VERSION  = 1.21.1
BUSYBOX_SOURCE   = http://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

E2FSPROGS_VERSION = 1.42.5
E2FSPROGS_SOURCE = http://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v$(E2FSPROGS_VERSION)/e2fsprogs-$(E2FSPROGS_VERSION).tar.gz

DIALOG_VERSION = 1.2-20130523
DIALOG_SOURCE = ftp://invisible-island.net/dialog/dialog-$(DIALOG_VERSION).tgz

NCURSES_HEADER = $(CLFS)/usr/include/ncurses.h

.PHONY: all check-root busybox e2fsprogs dialog initrd clean distclean

all: initrd

clean: busybox-clean e2fsprogs-clean dialog-clean initrd-clean

distclean: busybox-distclean e2fsprogs-clean dialog-distclean initrd-distclean

check-root:
	@if [ "$$UID" != "0" ]; then \
		echo "You need to be root to do this."; \
		echo "Now you should run 'make initrd' as root to finish compilation or 'sudo make initrd'."; \
		exit 1; \
	fi

$(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2:
	wget -P $(WORK) -c $(BUSYBOX_SOURCE)

$(WORK)/busybox-$(BUSYBOX_VERSION): $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2 $(TOPDIR)/busybox-$(BUSYBOX_VERSION).config $(WORK)/fix-resource_header.patch
	tar -C $(WORK) -xvjf $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2
	cd $(WORK)/busybox-$(BUSYBOX_VERSION) && \
		patch -p1 -i $(WORK)/fix-resource_header.patch
	cp -v $(TOPDIR)/busybox-$(BUSYBOX_VERSION).config $(WORK)/busybox-$(BUSYBOX_VERSION)/.config
	touch $(WORK)/busybox-$(BUSYBOX_VERSION)

$(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox: $(WORK)/busybox-$(BUSYBOX_VERSION)
	export PATH=$(CROSSTOOLS)/bin:$$PATH &&  \
	export LD_LIBRARY_PATH=$(CROSSTOOLS)/lib:$$LD_LIBRARY_PATH && \
	make -j1 -C $(WORK)/busybox-$(BUSYBOX_VERSION) ARCH=arm CROSS_COMPILE=$(TARGET)- install && \
	install -D -m 0755 $(WORK)/busybox-$(BUSYBOX_VERSION)/examples/udhcp/simple.script $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/usr/share/udhcpc/default.script && \
	$(TARGET)-strip $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox && \
	touch $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox

busybox: $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/bin/busybox

busybox-clean:
	rm -vrf $(WORK)/busybox-$(BUSYBOX_VERSION)

busybox-distclean: busybox-clean
	rm -vf $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2

$(WORK)/e2fsprogs-$(E2FSPROGS_VERSION).tar.gz:
	wget -P $(WORK) -c $(E2FSPROGS_SOURCE)

$(WORK)/e2fsprogs-$(E2FSPROGS_VERSION): $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION).tar.gz
	tar -C $(WORK) -xvzf $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION).tar.gz
	touch $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)

$(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)/misc/mke2fs: $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)
	export PATH=$(CROSSTOOLS)/bin:$$PATH &&  \
        export LD_LIBRARY_PATH=$(CROSSTOOLS)/lib:$$LD_LIBRARY_PATH && \
        cd $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION) && \
                ./configure --build=$(BUILD) --host=$(TARGET) --prefix=/usr --with-root-prefix= \
                --mandir=/usr/man --disable-symlink-install --disable-nls --disable-compression \
                --disable-htree --disable-elf-shlibs --disable-bsd-shlibs --disable-profile \
                --disable-checker --disable-jbd-debug --disable-blkid-debug --disable-testio-debug \
                --enable-libuuid --enable-libblkid --disable-libquota --disable-debugfs --disable-imager \
                --disable-resizer --disable-defrag --disable-fsck --disable-e2initrd-helper \
                --disable-tls --disable-rpath && \
                make V=1 CFLAGS="$(CFLAGS) -static" LDFLAGS="$(LDFLAGS) -static" && \
                $(TARGET)-strip $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)/misc/mke2fs && \
                touch $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)/misc/mke2fs

e2fsprogs: $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)/misc/mke2fs

e2fsprogs-clean:
	rm -vrf $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)

e2fsprogs-distclean:
	rm -vf $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION).tar.bz2

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

dialog: $(NCURSES_HEADER) $(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog

dialog-clean:
	rm -vrf $(WORK)/dialog-$(DIALOG_VERSION)

dialog-distclean: dialog-clean
	rm -vf $(WORK)/dialog-$(DIALOG_VERSION).tgz

$(WORK)/mnt:
	mkdir -p $(WORK)/mnt

$(WORK)/initrd.gz: check-root busybox e2fsprogs dialog $(WORK)/mnt $(TOPDIR)/filesystem $(TOPDIR)/mkinitrd.sh
	sh mkinitrd.sh --name=$(WORK)/initrd.gz --size=4096
	cd $(WORK) && gunzip -v initrd.gz
	mount -v -t ext2 -o loop,rw $(WORK)/initrd $(WORK)/mnt
	cp -dRv $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/* $(WORK)/mnt
	install -v -m 0755 $(WORK)/e2fsprogs-$(E2FSPROGS_VERSION)/misc/mke2fs $(WORK)/mnt/sbin
	for i in 2 3 4 4dev; do \
		ln -s mke2fs $(WORK)/mnt/sbin/mkfs.ext$$i; \
	done
	install -v -m 0755 $(WORK)/dialog-$(DIALOG_VERSION)/_install/usr/bin/dialog $(WORK)/mnt/usr/bin
	cp -dRv $(CLFS)/lib/libnss_{files*,dns*} $(CLFS)/lib/libresolv* $(WORK)/mnt/lib
	install -d  $(WORK)/mnt/usr/share/terminfo
	cp -dRv $(CLFS)/usr/share/terminfo/v $(WORK)/mnt/usr/share/terminfo
	install -v -m 0644 $(TOPDIR)/filesystem/{fstab,inittab,profile,protocols,*.conf} $(WORK)/mnt/etc
	install -v -m 0664 $(TOPDIR)/filesystem/group $(WORK)/mnt/etc
	install -v -m 0600 $(TOPDIR)/filesystem/passwd $(WORK)/mnt/etc
	install -v -m 0400 $(TOPDIR)/filesystem/shadow $(WORK)/mnt/etc
	install -v -m 0755 $(TOPDIR)/filesystem/rc $(WORK)/mnt/etc && \
	install -v -m 0755 $(TOPDIR)/filesystem/{setup,setup-chroot,crux} $(WORK)/mnt/usr/bin && \
	ln -s bin/busybox $(WORK)/mnt/init
	/sbin/ldconfig -r $(WORK)/mnt
	umount -v $(WORK)/mnt
	cd $(WORK) && gzip -v initrd
	touch $(WORK)/initrd.gz

initrd: $(WORK)/initrd.gz

initrd-clean: check-root
	rm -rvf $(WORK)/initrd.gz $(WORK)/mnt

initrd-distclean: initrd-clean

# End of file
