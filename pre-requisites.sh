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
  git \
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
