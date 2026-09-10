#
# Copyright (C) 2026 Higen (harimu63)
# Licensed under the GNU General Public License v3.0
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for sing-box (DanBox)
LUCI_DESCRIPTION:=Run, monitor, edit config, and view logs for SagerNet/sing-box core, directly from LuCI. \
	Does NOT bundle or build sing-box itself — install the sing-box binary separately.
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-danbox
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=Higen <https://github.com/harimu63>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
