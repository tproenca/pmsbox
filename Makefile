
DIST ?= trusty
DIST_URL := http://ports.ubuntu.com/ubuntu-ports/
DIST_ARCH := armhf

ROOTFS_DIR := rootfs
DIST_DIR := dist
TARGET_DIR := target
VERSION := 1.0.0

.PHONY: all
all: build

.PHONY: clean
clean: delete-rootfs
	rm -rf $(wildcard $(DIST_DIR) $(TARGET_DIR))

.PHONY: distclean
distclean: delete-rootfs
	rm -rf $(wildcard $(ROOTFS_DIR).base $(ROOTFS_DIR).base.tmp)

.PHONY: delete-rootfs
delete-rootfs:
	if mountpoint -q $(ROOTFS_DIR).plex/proc ; then umount $(ROOTFS_DIR).plex/proc ; fi
	if mountpoint -q $(ROOTFS_DIR).plexsuite/dev ; then umount $(ROOTFS_DIR).plexsuite/dev ; fi
	rm -rf $(wildcard $(ROOTFS_DIR).plex $(ROOTFS_DIR).plexsuite)
	
.PHONY: build
build: odroidc1

$(ROOTFS_DIR).base:
	if test -d "$@.tmp"; then rm -rf "$@.tmp" ; fi
	mkdir -p $@.tmp/usr/bin
	cp `which qemu-arm-static` $@.tmp/usr/bin
	debootstrap --variant=buildd --arch=$(DIST_ARCH) $(DIST) $@.tmp $(DIST_URL)
	ln -s /proc/mounts $@.tmp/etc/mtab
	mv $@.tmp $@
	touch $@

$(ROOTFS_DIR).plex: $(ROOTFS_DIR).base
	rsync --quiet --archive --devices --specials --hard-links --acls --xattrs --sparse $(ROOTFS_DIR).base/* $@
	cp rootfs.setup $@
	cp rootfs.installer $@
	cp system.install $@/00system.install
	cp plex.install $@/01plex.install
	mount -o bind /proc $@/proc
	chroot $@ /bin/sh /rootfs.setup $(DIST) $(DIST_URL)
	chroot $@ /bin/sh /rootfs.installer
	umount $@/proc
	rm $@/01plex.install
	rm $@/00system.install
	rm $@/rootfs.installer
	rm $@/rootfs.setup
	touch $@

$(ROOTFS_DIR).plexsuite: $(ROOTFS_DIR).plex
	rsync --quiet --archive --devices --specials --hard-links --acls --xattrs --sparse $(ROOTFS_DIR).plex/* $@
	cp rootfs.installer $@
	cp suite.install $@
	mount -o bind /dev $@/dev
	chroot $@ /bin/sh /rootfs.installer
	umount $@/dev
	rm $@/suite.install
	rm $@/rootfs.installer
	touch $@

$(DIST_DIR)/pmsbox-odroidc1_$(VERSION).img.xz: $(ROOTFS_DIR).plex
	mkdir -p $(DIST_DIR)
	/bin/sh createimg.odroidc1 $(ROOTFS_DIR).plex $(TARGET_DIR) $(basename $@)
	xz -9 $(basename $@)
	touch $@

$(DIST_DIR)/pmsbox-suite-odroidc1_$(VERSION).img.xz: $(ROOTFS_DIR).plexsuite
	mkdir -p $(DIST_DIR)
	/bin/sh createimg.odroidc1 $(ROOTFS_DIR).plexsuite $(TARGET_DIR) $(basename $@)
	xz -9 $(basename $@)
	touch $@

odroidc1: $(DIST_DIR)/pmsbox-odroidc1_$(VERSION).img.xz $(DIST_DIR)/pmsbox-suite-odroidc1_$(VERSION).img.xz