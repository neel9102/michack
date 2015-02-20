
##### About SBINC01, pre installation #########
----------------------------
Linux sbinc01 3.13.0-32-generic 
#57-Ubuntu SMP Tue Jul 15 03:51:08 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux


1. # Make sure you can see the MIC card from the PCI bus: 
sudo lspci | grep processor
## 42:00.0 Co-processor: Intel Corporation Xeon Phi coprocessor SE10/7120 series (rev 20)


2. in BIOS 
*Advanced settings* then
*PCI settings* then
*Memory Mapped I/O above 4GB* [Enable]
#or
lspci -s 42:00.0 -vv
# and noticed [size=16G]


3. Install other necessary ubuntu packagesb the alien package: 
sudo apt-get install alien
sudo apt-get install sysv-rc-conf
sudo apt-get install build-essential linux-headers-generic


4. other requrement tests according to intel:
# source: http://registrationcenter.intel.com/irc_nas/5017/readme.txt
# SSH Access and Configuration for the Intel(R) Xeon Phi(TM) Coprocessor

# For each user in /etc/passwd (including root), if SSH key files are found 
# in the user's ".ssh" directory, those keys are also populated to the Intel(R) 
# Xeon Phi(TM) coprocessor's file system.

cd ~
ssh-keygen
# Your identification has been saved in /home/ladmin/.ssh/id_rsa.
# Your public key has been saved in /home/ladmin/.ssh/id_rsa.pub.

# for roor
sudo ssh-keygen
# key are generated in /root/.ssh

# network demon, shows all the demons running
sudo sysv-rc-conf --list
sudo sysv-rc-conf networking on






###### Building and Installing Kernel Modules ###########
####------------------------------------------------#####




# download the mpss-modules from following site.
# The source is patched to work with Linux Kernel 3.13.0, 
# it was only tested on Ubuntu 14.04, but should work on 
# any distro since the Kernel version is 3.13.0 (not tested with newer kernel versions).
https://github.com/pentschev/mpss-modules

# copy file to sbinc01
scp rkawsar@192.168.0.119:/home/rkawsar/Downloads/mpss-modules-master.zip /home/ladmin/Downloads
cd ~/Downloads
# unziping the zip file
unzip mpss-modules-master.zip
cd mpss-modules-master

# downloads 3.4.2 version from intel website
# https://software.intel.com/en-us/articles/intel-manycore-platform-software-stack-mpss#lx34rel
wget http://registrationcenter.intel.com/irc_nas/5017/mpss-3.4.2-linux.tar
# download the source files
wget http://registrationcenter.intel.com/irc_nas/5017/mpss-src-3.4.2.tar


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

#### uncomfortable massge: no talloc stackframe at ../source3/param/loadparm.c:4864, leaking memory
# and that is because of samba client


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

sudo touch /etc/ld.so.conf.d/zz_x86_64-compat.conf
sudo gedit /etc/ld.so.conf.d/zz_x86_64-compat.conf
# add following line 
/usr/lib64

sudo touch /etc/ld.so.conf.d/mic.conf
sudo gedit /etc/ld.so.conf.d/mic.conf
# add following line 
/usr/lib64


sudo ldconfig

sudo depmod
sudo modprobe mic
sudo micctrl -s
sudo micctrl --initdefaults

# check error massahges
dmesg |less |grep mic

# uncomfortable warnings:
# [Warning] mic0: Generating compatibility network config file /opt/intel/mic/filesystem/mic0/etc/sysconfig/network/ifcfg-mic0 for IDB.
# [Warning]       This may be problematic at best and will be removed in a future release, Check with the IDB release.

sudo micctrl -s
# mic0: reset failed


########### Configuring the Coprocessor (post Installation) ###############
###########################################################################

# ensure root has the ssh-key
sudo ls /root/.ssh
# key found ...id_rsa, id_rsa.pub

# command creates and populates default configuration values
# into Intel MPSS specific configuration files 
# default.conf and micN.conf at /etc/mpss/
micctrl --initdefaults

# setup the demon in corret location
sudo cp /etc/mpss/mpss.ubuntu /etc/init.d/mpss
# check if the mpss demon is in the right place
ls /etc/init.d/

# confirmed
# now lets start the mpss service
sudo service mpss start 

# it has started without any complain
# now start the NFS configuration, which is the easiest way to share 
# files between the host system and the coprocessor

sudo apt-get install nfs-kernel-server
sudo service nfs-kernel-server restart
# ERROR: * Not starting NFS kernel daemon: no exports.
# but i kept going

mkdir /micNfs
# It should be then configured for NFS export by adding the line 

sudo gedit /etc/exports
# add the following line
# no_root_squash will give you the root permission to access/ create files on a NFS Server.
# Default is root_squash.

/micNfs 172.31.1.1(rw,no_root_squash)

#L ater the coprocessor machine should be allowed to mount this filesystem, 
# and this can be done by adding the line 

sudo gedit /etc/hosts.allow

# add the following line
ALL:172.31.1.1 to file 

# restart the nfs-kernel-server
sudo service nfs-kernel-server restart

# this time it started
# Now the filesystem can be exported by running

sudo exportfs -a


# NFS filesystem should be added to MPSS configuration, which is simply done with the 
sudo micctrl --addnfs=172.31.1.254:/micNfs --dir=/micNfs
# [Warning] mic0: Server 172.31.1.254 may not be reachable if the interface is not routed out of the host
# [Warning] Modified existing NFS entry for MIC card path '/micNfs'


# Now the MPSS service must be stopped to finish the remaining configuration
sudo service mpss stop


# A user for MIC called micuser with user ID 400 is then created along with a group of same name by running
useradd -U -m -u 400 micuser

# The group ID of micuser is then changed to 400 as well with
sudo groupmod -g 400 micuser

# A directory to hold files for micuser must be created
# and given the correct permissions
sudo mkdir -p /var/michome/micuser
sudo chown micuser /var/michome/micuser

# The parent directory for micuser NFS home should also be exported by adding the line 
sudo gedit /etc/exports
# add the following line
/var/michome 172.31.0.0/16(rw)

# The directory shall now be exported 
sudo exportfs -a

# and NFS service restarted 
sudo service nfs-kernel-server restart

# The MPSS should be configure to mount the /home directory 
# on the Phi’s OS from host’s /var/michome
sudo micctrl --addnfs=/var/michome --dir=/home

# Finally, the MPSS service is restarted
sudo service mpss restart

# and NFS filesystems mounted. 
sudo mount -a


# Now change the configuration
# check the current configurations. it tells you things you need to know
sudo micctrl --config



##################### -#-#### now mic status check #### - #####################

sudo miccheck

# Status: FAIL
# Failure: /sbin/lspci could not be found in the system

######## diogonistic ##########
sudo find / -name lspci

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

# check the mic device status
sudo micctrl -s

# mic0: reset failed

# reset the list of xeon phi cards
sudo micctrl -rw 


#####
test flash version

micflash -vv -update -device all

mic0: Flash image: /usr/share/mpss/flash/EXT_HP2_C0_0390-02.rom.smc










###################################################################
##### after restarting the machine

# uname -a says the karnel changed to "3.13.0-45-generic"
# maybe this was becase of the sudo apt-get upgrade command
# any way so i recompile the kernel again

# install the mpss module again
cd ~/Downloads/mpss-3.4.2/src/mpss-modules-3.4.2
make
sudo make install


1. This update the cache
sudo ldconfig
2. check is the module is available
sudo lsmod
3. depmod will output a dependency list suitable for the modprobe utility.
sudo depmod
4. load the mic module
sudo modprobe mic
5. start the mpss services
sudo service mpss start
6. check the mpss log
sudo gedit  /var/log/mpssd



#######################################################
#### micflash hack

sudo micflash -version
# micflash: Tool version: 3.4.2-1

sudo micflash -devinfo
# micflash: mic0: Failed to switch to maintenance mode: write: /sys/class/mic/mic0/state: Input/output error


# check the running services
ps -A | grep mpss
# no mpss is running


sudo micflash -update -device all
No image path specified - Searching: /usr/share/mpss/flash
mic0: Flash image: /usr/share/mpss/flash/EXT_HP2_C0_0390-02.rom.smc


# reset the list of xeon phi cards
sudo micctrl


#####
# test flash version

micflash -vv -update -device all
#mic0: Flash image: /usr/share/mpss/flash/EXT_HP2_C0_0390-02.rom.smc

### restarted the machine and then 

sudo micflash -update -device all
# micflash: Failed to get cards info: host driver is not loaded: No such file or directory

sudo micinfo
# Driver Version : NotAvailable

# resintall the deriver
cd  ~/Downloads/mpss-modules-master
make
sudo make install
sudo depmod
sudo modprobe mic

micinfo
# the driver has loded

# now check the mic status
sudo micctrl -s












# dmidecode -s bios-verison


################################################################################
### It is also necessary to enable the service start during boot and stop 
#### during reboot/shutdown, which can be done by executing 
update-rc.d mpss defaults 99 10
##################################################################################




# Add directory /usr/lib64, containing the MPSS shared libraries, to the dynamic linker:
echo '/usr/lib64' > /etc/ld.so.conf.d/mic.conf
ldconfig

