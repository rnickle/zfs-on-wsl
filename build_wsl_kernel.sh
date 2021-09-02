#!/bin/bash

# Root trap
if [[ "$EUID" -ne 0 ]]; then echo "-E- $0 should run as root."; exit; fi

VERBOSE="false"

while getopts ":b:fhj:k:n:qs:vz:" opt; do
  case $opt in
    b)
      OKBUILTIN=$OPTARG
      ;;
    f)
      echo "-I- forcing download of source packages"
      ODLFORCE=true
      ;;
    h)
      echo "Usage: $0 [-f] [-h] [-b (yes|no)] [-k kernel] [-n name] [-s vars-file] [-z zfs]"
      echo "       -b built-in"
      echo "       -f force download of packages"
      echo "       -h this usage page"
      echo "       -j number-of-make-jobs"
      echo "       -k kernel-version"
      echo "       -n build-name"
      echo "       -q build for Hyper-V"
      echo "       -s source vars-file"
      echo "       -v verbose"
      echo "       -z zfs-version"
      exit 1
      ;;
    j)
      ONPROC=$OPTARG
      ;;
    k)
      OKVER=$OPTARG
      ;;
    q)
      OHYPERV="true"
      ;;
    n)
      OKNAME=$OPTARG
      ;;
    s)
      echo "-I- sourcing $OPTARG"
      source "$OPTARG"
      ;;
    v)
      VERBOSE="true"
      ;;
    z)
      OZVER=$OPTARG
      ;;
    :)
      echo "-E- Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    *)
      echo "-E- Invalid flags $opt $OPTARG" >&2
      exit 1
      ;;
  esac
done

# Exported variables
# * need to export for some subprocesses (sed, builds)
# * reasonable defaults for this release
export KERNELVER=${OKVER:-"5.13.12"}  # https://www.kernel.org/
export ZFSVER=${OZVER:-"2.1.0"}  # https://zfsonlinux.org/
export KERNELNAME=${OKNAME:-"zfswsl-kmod"}

# https://github.com/openzfs/zfs/issues/1324
if [[ ${OKBUILTIN:-no} != "no" ]]; then
  KERNELBUILTIN="--enable-linux-builtin=yes"
else
  KERNELBUILTIN=""
fi

if [[ ${VERBOSE} == "true" ]]; then
  echo "-I- verbose mode set"
  echo "-I- module as kernel built-in: $OKBUILTIN"
  echo "-I- configure directive for built-in: $KERNELBUILTIN"
  echo "-I- kernel version: $KERNELVER"
  echo "-I- kernal build name: $KERNELNAME"
  echo "-I- ZFS version: $ZFSVER"
  set -xe
fi

# Install pre-requisites
export DEBIAN_FRONTEND=noninteractive
apt-get update && \
apt-get upgrade -y && \
apt-get install -y tzdata && \
apt-get install -y \
  alien \
  autoconf \
  automake \
  bc \
  binutils \
  bison \
  build-essential \
  curl \
  dkms \
  fakeroot \
  flex \
  gawk \
  libaio-dev \
  libattr1-dev \
  libblkid-dev \
  libelf-dev \
  libffi-dev \
  libssl-dev \
  libtool \
  libudev-dev \
  python3 \
  python3-cffi \
  python3-dev \
  python3-setuptools \
  uuid-dev \
  wget \
  zlib1g-dev

LINUX_SRC=/usr/src/linux-${KERNELVER}-${KERNELNAME}
ZFS_SRC=/usr/src/zfs-${ZFSVER}-for-linux-${KERNELVER}-${KERNELNAME}
LINUX_TAR=linux-${KERNELVER}.tar.xz
ZFS_TAR=zfs-${ZFSVER}.tar.gz
LINUX_URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/${LINUX_TAR}
ZFS_URL=https://github.com/openzfs/zfs/releases/download/zfs-${ZFSVER}/${ZFS_TAR}
WSL_CFG_URL=https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/master/Microsoft/config-wsl

# Create temp build dir (delete it first if we find it already exists)
if [[ -d "/tmp/kbuild" ]]; then rm -rf /tmp/kbuild; fi
mkdir /tmp/kbuild

# Only download and extract if does not exist or ODLFORCE
if [[ ! -d ${LINUX_SRC} || ${ODLFORCE:-false} == "true" ]]
then
  # Download and extract the latest stable kernel source
  wget "$LINUX_URL" -O /tmp/kbuild/"$LINUX_TAR"
  tar -xf /tmp/kbuild/"$LINUX_TAR" -C /tmp/kbuild

  # Move our kernel directory to reflect our custom name
  cp -rf /tmp/kbuild/linux-"$KERNELVER" /usr/src/linux-"$KERNELVER"-"$KERNELNAME"

  # Add the WSL2 kernel config from upstream into our extracted kernel directory
  wget ${WSL_CFG_URL} -O /usr/src/linux-"$KERNELVER"-"$KERNELNAME"/.config
fi

# Use our custom localversion so we can tell when we've actually successfully installed one of our custom kernels
sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-${KERNELNAME}"/g' /usr/src/linux-"$KERNELVER"-"$KERNELNAME"/.config

# remove any residual ZFS configuration from previous run
# (otherwise modpost might fail with symbol errors)
sed -i '/.*CONFIG_ZFS.*/d' "$LINUX_SRC"/.config

# Enter the kernel directory
cd "$LINUX_SRC"

# Update our .config file by accepting the defaults for any new kernel
# config options added to the kernel since the Microsoft config was
# generated.
make olddefconfig

# Check and resolve any dependencies needed before building the kernel
make prepare

make -j "$ONPROC"

# Only download and extract if does not exist or ODLFORCE
if [[ ! -d "$ZFS_SRC" || ${ODLFORCE:-false} == "true" ]]; then
  # Download and extract the latest ZFS source
  wget "$ZFS_URL" -O /tmp/kbuild/"$ZFS_TAR"
  tar -xf /tmp/kbuild/"$ZFS_TAR" -C /tmp/kbuild

  # Move our ZFS directory to reflect our custom name
  cp -rf /tmp/kbuild/zfs-"$ZFSVER" "$ZFS_SRC"
fi

# Enter the ZFS module directory
cd "$ZFS_SRC"

# Run OpenZFS autogen.sh script
./autogen.sh

# Configure the OpenZFS modules
# See: https://openzfs.github.io/openzfs-docs/Developer%20Resources/opt/kbuilding%20ZFS.html
./configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share "$KERNELBUILTIN" --with-linux="$LINUX_SRC" --with-linux-obj="$LINUX_SRC"

# Run the copy-builtin script
./copy-builtin "$LINUX_SRC"

# Build ZFS!
make -s -j "$ONPROC"
make install

# Return to the kernel directory
cd "$LINUX_SRC"

# Make sure that we're going to build ZFS support when we build our kernel
sed -i '/.*CONFIG_ZFS.*/d' "$LINUX_SRC"/.config
if [[ ${OKBUILTIN} != "no" ]]; then
  echo "CONFIG_ZFS=y" >> "$LINUX_SRC"/.config
else
  echo "CONFIG_ZFS=m" >> "$LINUX_SRC"/.config
fi

# Build our kernel and install the modules into /lib/modules!
make -j "$ONPROC"
make modules_install

# Copy our kernel to C:\ZFSonWSL\bzImage
# (We don't save it as bzImage in case we overwrite the kernel we're actually running
# so after the build process is done, the user will need to shutdown WSL and then rename
# the bzImage-new kernel to bzImage)
if [[ ${OHYPERV:-false} == "false" ]]; then
  mkdir -p /mnt/c/ZFSonWSL
  cp -fv "$LINUX_SRC"/arch/x86/boot/bzImage /mnt/c/ZFSonWSL/bzImage-new
fi

# Tar up the build directories for the kernel and for ZFS
# Mostly useful for our GitLab CI process but might help with redistribution
cd /tmp/kbuild
tar -czf linux-"$KERNELVER"-"$KERNELNAME".tgz "$LINUX_SRC"
tar -czf zfs-"$ZFSVER"-for-"$KERNELVER"-"$KERNELNAME".tgz "$ZFS_SRC"
