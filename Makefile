# 
# initrd.git/Makefile
#

TARGET = arm-crux-linux-gnueabi
DEVICE = versatile

TOPDIR = $(shell pwd)
WORK = $(TOPDIR)/work
CLFS = $(TOPDIR)/../toolchain/clfs
CROSSTOOLS = $(TOPDIR)/../toolchain/crosstools


KERNEL_PATH = $(TOPDIR)/../kernel/$(DEVICE)
KERNEL_VERSION = $(shell grep '^KERNEL_VERSION = ' $(KERNEL_PATH)/Makefile | sed 's|KERNEL_VERSION = ||')

BUSYBOX_SOURCE   = http://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_VERSION  = 1.14.3

.PHONY: all check-root busybox initrd clean distclean

all: busybox initrd

clean: busybox-clean initrd-clean

dist-clean: busybox-distclean initrd-distclean

check-root:
	@if [ "$$UID" != "0" ]; then \
		echo "You need to be root to do this."; \
    echo "Now you should run 'make initrd' as root to finish compilation or 'sudo make initrd'."; \
		exit 1; \
	fi

$(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2:
	wget -P $(WORK) -c http://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

$(WORK)/busybox-$(BUSYBOX_VERSION): $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2 $(TOPDIR)/busybox-$(BUSYBOX_VERSION).config $(WORK)/busybox-$(BUSYBOX_VERSION)-make382.patch
	tar -C $(WORK) -xvjf $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2
	cd $(WORK)/busybox-$(BUSYBOX_VERSION) && \
		patch -p1 -i $(WORK)/busybox-$(BUSYBOX_VERSION)-make382.patch
	cp -v $(TOPDIR)/busybox-$(BUSYBOX_VERSION).config $(WORK)/busybox-$(BUSYBOX_VERSION)/.config
	touch $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2

$(WORK)/busybox-$(BUSYBOX_VERSION)/_install: $(WORK)/busybox-$(BUSYBOX_VERSION)
	export PATH=$(CROSSTOOLS)/bin:$$PATH &&  \
	export LD_LIBRARY_PATH=$(CROSSTOOLS)/lib:$$LD_LIBRARY_PATH && \
	make -C $(WORK)/busybox-$(BUSYBOX_VERSION) ARCH=arm CROSS_COMPILE=$(TARGET)- install
	touch $(WORK)/busybox-$(BUSYBOX_VERSION)/_install

busybox: $(WORK)/busybox-$(BUSYBOX_VERSION)/_install

busybox-clean:
	rm -vrf $(WORK)/busybox-$(BUSYBOX_VERSION)

busybox-distclean:
	rm -vf $(WORK)/busybox-$(BUSYBOX_VERSION).tar.bz2

$(WORK)/mnt:
	mkdir -p $(WORK)/mnt

$(WORK)/initrd-$(KERNEL_VERSION).gz: check-root busybox $(KERNEL_PATH) $(WORK)/mnt $(TOPDIR)/filesystem $(TOPDIR)/mkinitrd.sh
	sh mkinitrd.sh --name=$(WORK)/initrd-$(KERNEL_VERSION).gz --size=4096
	cd $(WORK) && gunzip -v initrd-$(KERNEL_VERSION).gz
	mount -v -t ext2 -o loop,rw $(WORK)/initrd-$(KERNEL_VERSION) $(WORK)/mnt
	cp -dRv $(WORK)/busybox-$(BUSYBOX_VERSION)/_install/* $(WORK)/mnt
	#make -C $(KERNEL_PATH)/work/linux-$(KERNEL_VERSION) ARCH=arm INSTALL_MOD_PATH=$(WORK)/mnt modules_install
	cp -dRv $(CLFS)/lib/libnss_{files*,dns*} $(CLFS)/lib/libresolv* $(WORK)/mnt/lib 
	install -v -m 0644 $(TOPDIR)/filesystem/{fstab,inittab,profile,protocols,*.conf} $(WORK)/mnt/etc
	install -v -m 0755 $(TOPDIR)/filesystem/rc $(WORK)/mnt/etc && \
	install -v -m 0755 $(TOPDIR)/filesystem/crux $(WORK)/mnt/usr/bin && \
	/sbin/ldconfig -r $(WORK)/mnt
	umount -v $(WORK)/mnt
	cd $(WORK) && gzip -v initrd-$(KERNEL_VERSION)
	touch $(WORK)/initrd-$(KERNEL_VERSION).gz

initrd: $(WORK)/initrd-$(KERNEL_VERSION).gz

initrd-clean: check-root
	rm -rf initrd-$(KERNEL_VERSION).gz

initrd-distclean: initrd-clean

# End of file
