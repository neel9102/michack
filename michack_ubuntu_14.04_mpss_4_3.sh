
##### About SBINC01, pre installation #########
# Linux sbinc01 3.13.0-32-generic 
# 57-Ubuntu SMP Tue Jul 15 03:51:08 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux
# ---------------------------------------------------------------------------

# 1. Make sure you can see the MIC card from the PCI bus: 
sudo lspci | grep processor
## 42:00.0 Co-processor: Intel Corporation Xeon Phi coprocessor SE10/7120 series (rev 20)

# 2. in BIOS 
# *Advanced settings* then
# *PCI settings* then
# *Memory Mapped I/O above 4GB* [Enable]


# 3. Install other necessary ubuntu packagesb the alien package: 
sudo apt-get install alien
sudo apt-get install sysv-rc-conf
sudo apt-get install linux-headers-`uname -r` build-essential


# 4. other requrement tests according to intel:
# for roor (key are generated in /root/.ssh)
sudo ssh-keygen

# network demon, shows all the demons running
sudo sysv-rc-conf --list
sudo sysv-rc-conf networking on


###### Building and Installing Kernel Modules ###########
####------------------------------------------------#####

# downloads 3.4.3 version from intel website
# https://software.intel.com/en-us/articles/intel-manycore-platform-software-stack-mpss#lx34rel
wget http://registrationcenter.intel.com/irc_nas/5017/mpss-3.4.3-linux.tar
# download the source files
wget http://registrationcenter.intel.com/irc_nas/5017/mpss-src-3.4.3.tar

# unzip the linax tar
tar xvf mpss-3.4.2-linux.tar
tar xvf mpss-src-3.4.2.tar
~/Downloads/mpss-3.4.2/src
tar -jxvf mpss-modules-3.4.2.tar.bz2

gedit Makefile
# replace export MIC_CARD_ARCH to 
export MIC_CARD_ARCH := k1om

gedit ./host/linux.c
# find the function mic_ctx->sysfs_state = sysfs_get_dirent and change the next line to following line
#if (LINUX_VERSION_CODE > KERNEL_VERSION(2,6,35)) && (KERNEL_VERSION(3,13,0) > LINUX_VERSION_CODE)

# now make and make install
make
sudo make install

# black listing mic_host
sudo rmmod mic_host
sudo touch /etc/modprobe.d/blacklist-mic-host.conf
sudo gedit /etc/modprobe.d/blacklist-mic-host.conf
# add the following line
blacklist mic_host


# Convert the rpm to deb packages with alien and install
cd ~/Downloads/mpss-3.4.2
sudo alien --scripts *.rpm
sudo dpkg -i *.deb
# dmesg and lsmod
#### uncomfortable massage: install-info: warning: no info dir entry in `/usr/share/info/netperf.info.gz'

# to make sure binaries are available
echo "/usr/lib64" > /etc/ld.so.conf.d/zz_x86_64-compat.conf
echo "/usr/lib64" > /etc/ld.so.conf.d/mic.conf

# loding modules and intiate default mic settings
sudo ldconfig
sudo depmod
sudo modprobe mic
sudo micctrl -s
sudo micctrl --initdefaults

# uncomfortable warnings:
# [Warning] mic0: Generating compatibility network config file /opt/intel/mic/filesystem/mic0/etc/sysconfig/network/ifcfg-mic0 for IDB.
# [Warning]       This may be problematic at best and will be removed in a future release, Check with the IDB release.

sudo  micctrl -rw
# mic0: reset failed

# setup the demon in corret location
sudo cp /etc/mpss/mpss.ubuntu /etc/init.d/mpss
# check if the mpss demon is in the right place
ls /etc/init.d/

# now lets start the mpss service
sudo service mpss start
sudo service mpss stop

##################### -#-#### now mic status check #### - #####################
###############################################################################

sudo miccheck
# Status: FAIL
# Failure: /sbin/lspci could not be found in the system

# found in /usr/bin/lspci
# so try creating a softlink
sudo ln -s /usr/bin/lspci /sbin/lspci

# now run micchek again...
sudo miccheck

# Status: FAIL
# Failure: mpssd daemon not running
# check mpss status

sudo service mpss status
# mpss is stopped so start it and run the mickcheck
sudo service mpss start
# check the running services
ps -A | grep mpss

# passed and now run the miccheck again
sudo miccheck

# Executing default tests for device: 0
#  Test 4 (mic0): Check device is in online state and its postcode is FF ... fail
#    device is not online: reset failed
# Status: FAIL
# Failure: A device test failed


###   ############### flashing the mic ###############################
##########################################################################

sudo micflash -version
# micflash: Tool version: 3.4.2-1

micflash -vv -update -device all
# micflash: mic0: Failed to switch to maintenance mode: write: /sys/class/mic/mic0/state: Input/output error

# machin rebooted and disconnected from power supply

sudo micflash -update -device all
# micflash: Failed to get cards info: host driver is not loaded: No such file or directory

sudo modprobe mic
sudo micflash -devinfo
# micflash: mic0: Failed to switch to maintenance mode: write: /sys/class/mic/mic0/state: Input/output error
