obj-m += miop-reg.o
obj-m += miop-ep.o
obj-m += miop-ep-net.o
obj-m += pcie-ep-rk35.o
miop-reg-objs := reg.o
miop-ep-objs := ep.o meta_ep.o
miop-ep-net-objs := net.o meta_net.o
pcie-ep-rk35-objs := pcie.o meta_pcie.o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
OBJCOPY ?= objcopy

PKG_NAME := miop-driver-service
PKG_VER := $(shell uname -r)
PKG_ARCH := arm64
DEB_STAGING := deb_build/$(PKG_NAME)_$(PKG_VER)_$(PKG_ARCH)

all: shared_c
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	-$(OBJCOPY) --remove-section __kcrctab --remove-section __kcrctab_gpl miop-reg.ko 2>/dev/null || true
	-$(OBJCOPY) --remove-section __kcrctab --remove-section __kcrctab_gpl miop-ep.ko 2>/dev/null || true
	-$(OBJCOPY) --remove-section __kcrctab --remove-section __kcrctab_gpl miop-ep-net.ko 2>/dev/null || true
	-$(OBJCOPY) --remove-section __kcrctab --remove-section __kcrctab_gpl pcie-ep-rk35.ko 2>/dev/null || true

shared_c:
	@ln -sf meta.c meta_ep.c
	@ln -sf meta.c meta_reg.c
	@ln -sf meta.c meta_net.c
	@ln -sf meta.c meta_pcie.c

install: all
	install -d /lib/miop
	install -m 644 miop-reg.ko miop-ep.ko miop-ep-net.ko pcie-ep-rk35.ko /lib/miop/
	install -d /lib/systemd/system
	install -m 644 miop-driver.service /lib/systemd/system/
	install -d /usr/local/bin
	install -m 755 miop-driver-loader.sh /usr/local/bin/
	systemctl daemon-reload
	systemctl enable --now miop-driver.service

deb: all
	@rm -rf deb_build
	@mkdir -p $(DEB_STAGING)/DEBIAN
	@mkdir -p $(DEB_STAGING)/lib/miop
	@mkdir -p $(DEB_STAGING)/lib/systemd/system
	@mkdir -p $(DEB_STAGING)/usr/local/bin
	
	@echo "Package: $(PKG_NAME)" > $(DEB_STAGING)/DEBIAN/control
	@echo "Version: $(PKG_VER)" >> $(DEB_STAGING)/DEBIAN/control
	@echo "Architecture: $(PKG_ARCH)" >> $(DEB_STAGING)/DEBIAN/control
	@echo "Maintainer: Mixtile Community" >> $(DEB_STAGING)/DEBIAN/control
	@echo "Description: Service to load MIOP kernel modules at boot" >> $(DEB_STAGING)/DEBIAN/control
	
	@cp miop-reg.ko miop-ep.ko miop-ep-net.ko pcie-ep-rk35.ko $(DEB_STAGING)/lib/miop/
	@cp miop-driver.service $(DEB_STAGING)/lib/systemd/system/
	@cp miop-driver-loader.sh $(DEB_STAGING)/usr/local/bin/
	
	@chmod 644 $(DEB_STAGING)/lib/miop/*.ko
	@chmod 644 $(DEB_STAGING)/lib/systemd/system/miop-driver.service
	@chmod 755 $(DEB_STAGING)/usr/local/bin/miop-driver-loader.sh
	
	@dpkg-deb --build $(DEB_STAGING)
	@mv deb_build/*.deb ./

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	@rm -rf meta_ep.c meta_reg.c meta_net.c meta_pcie.c deb_build $(PKG_NAME)_$(PKG_VER)_$(PKG_ARCH).deb
