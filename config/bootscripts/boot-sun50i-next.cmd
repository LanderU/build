# DO NOT EDIT THIS FILE
#
# Please edit /boot/armbianEnv.txt to set supported parameters
#

# default values
setenv load_addr "0x44000000"
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv rootfstype "ext4"
setenv console "both"
setenv docker_optimizations "on"

# Print boot source
itest.b *0x10028 == 0x00 && echo "U-boot loaded from SD"
itest.b *0x10028 == 0x02 && echo "U-boot loaded from eMMC or secondary SD"
itest.b *0x10028 == 0x03 && echo "U-boot loaded from SPI"

echo "Boot script loaded from ${devtype}"

if load ${devtype} 0 ${load_addr} /boot/armbianEnv.txt || load ${devtype} 0 ${load_addr} armbianEnv.txt; then
	env import -t ${load_addr} ${filesize}
fi

# temp fix: increase cpufreq and bus clock / speeds things up with vanilla images
if test "${cpufreq_hack}" = "on"; then
	mw.l 0x1c2005c 1
	mw.l 0x1c20000 0x80001010
fi

# No display driver yet
if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=tty1"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} console=ttyS0,115200"; fi

setenv bootargs "root=${rootdev} rootwait rootfstype=${rootfstype} ${consoleargs} panic=10 consoleblank=0 loglevel=${verbosity} ${extraargs} ${extraboardargs}"

if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=memory swapaccount=1"; fi

load ${devtype} 0 ${fdt_addr_r} /boot/dtb/allwinner/${fdtfile} || load ${devtype} 0 ${fdt_addr_r} /dtb/allwinner/${fdtfile}
fdt addr ${fdt_addr_r}
fdt resize
for overlay_file in ${overlays}; do
	if load ${devtype} 0 ${load_addr} boot/dtb/allwinner/overlays/${overlay_prefix}-${overlay_file}.dtbo || load ${devtype} 0 ${load_addr} dtb/allwinner/overlays/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying DT overlay ${overlay_file}.dtbo"
		fdt apply ${load_addr}
	fi
done
if test "${mmc0-broken-cd}" = "on"; then
	fdt rm /soc/mmc@1c0f000/ cd-gpios
	fdt rm /soc/mmc@1c0f000/ cd-inverted
	fdt set /soc/mmc@1c0f000/ broken-cd
fi
load ${devtype} 0 ${ramdisk_addr_r} /boot/uInitrd || load ${devtype} 0 ${ramdisk_addr_r} uInitrd
load ${devtype} 0 ${kernel_addr_r} /boot/Image || load ${devtype} 0 ${kernel_addr_r} Image
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}

# Recompile with:
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
