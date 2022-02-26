FROM ubuntu:20.04

LABEL org.opencontainers.image.authors="johannes.dieterich@amd.com"

ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update
RUN apt upgrade -y
RUN apt install -y rpm wget sudo
RUN wget https://github.com/Kitware/CMake/releases/download/v3.22.2/cmake-3.22.2-Linux-x86_64.sh
RUN yes | sh cmake-3.22.2-Linux-x86_64.sh

RUN apt install -y git gcc build-essential bison vim libnuma-dev numactl libtbb-dev libelf-dev pkg-config libdrm-amdgpu1 libdrm2 pciutils libdrm-dev libudev-dev llvm-12-dev clang-12 libclang-12-dev xxd lld-12 clang-tools-12 liburi-encode-perl libfile-basedir-perl libfile-copy-recursive-perl libfile-listing-perl libfile-which-perl libglx-mesa0 libglx0 mesa-common-dev sudo wget gnupg2 git gcc libboost-dev bzip2 openmpi-bin flex libboost-all-dev vim libsqlite3-dev python3-setuptools numactl sqlite3

ENV CMAKE_PREFIX_PATH="/opt/rocm-5.0.0:${CMAKE_PREFIX_PATH}"

RUN apt install -y libncurses5-dev libncursesw5-dev libtinfo5

RUN wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
RUN echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
RUN apt update
RUN apt install -y rocm-llvm

ENV PATH="/cmake-3.22.2-linux-x86_64/bin:${PATH}"

WORKDIR /root
RUN git clone https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface
RUN mkdir -p /root/ROCT-Thunk-Interface/build
WORKDIR ROCT-Thunk-Interface/build/
RUN cmake -DCMAKE_INSTALL_PREFIX=/opt/rocm-5.0.0 -DCMAKE_CXX_COMPILER=/opt/rocm-5.0.0/bin/amdclang++ -DCMAKE_C_COMPILER=/opt/rocm-5.0.0/bin/amdclang -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make package
RUN dpkg -i *.deb

WORKDIR /root
RUN git clone https://github.com/RadeonOpenCompute/ROCm-Device-Libs.git -b amd-stg-open
RUN mkdir -p /root/ROCm-Device-Libs/build
WORKDIR ROCm-Device-Libs/build
RUN cmake -DCMAKE_CXX_COMPILER=/opt/rocm-5.0.0/bin/amdclang++ -DCMAKE_C_COMPILER=/opt/rocm-5.0.0/bin/amdclang -DROCM_DIR=/opt/rocm-5.0.0 -DCMAKE_INSTALL_PREFIX=/opt/rocm-5.0.0 -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make package
RUN dpkg -i *.deb

# link the bitcode into the right location
RUN ln -s /usr/amdgcn /opt/rocm-5.0.0/amdgcn

WORKDIR /root
RUN git clone https://github.com/RadeonOpenCompute/ROCR-Runtime
RUN mkdir -p /root/ROCR-Runtime/src/build
WORKDIR ROCR-Runtime/src/build
RUN cmake -DCMAKE_INSTALL_PREFIX=/opt/rocm-5.0.0 -DBITCODE_DIR=/usr/amdgcn/bitcode -DCMAKE_CXX_COMPILER=/opt/rocm-5.0.0/bin/amdclang++ -DCMAKE_C_COMPILER=/opt/rocm-5.0.0/bin/amdclang -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make package
RUN dpkg -i *.deb

WORKDIR /root
RUN git clone https://github.com/ROCm-Developer-Tools/hipamd.git
WORKDIR /root/hipamd
RUN git checkout bb16828
WORKDIR /root
RUN git clone https://github.com/ROCm-Developer-Tools/hip.git
WORKDIR /root/hip
RUN git checkout f3881c8
WORKDIR /root
RUN git clone https://github.com/ROCm-Developer-Tools/ROCclr.git
WORKDIR /root/ROCclr
RUN git checkout 319ab3e
WORKDIR /root
RUN git clone https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime.git
WORKDIR /root/ROCm-OpenCL-Runtime
RUN git checkout 226ea9c
WORKDIR /root

# comgr from source
RUN git clone -b roc-5.0.x https://github.com/RadeonOpenCompute/ROCm-CompilerSupport.git
RUN mkdir -p /root/ROCm-CompilerSupport/lib/comgr/build
WORKDIR ROCm-CompilerSupport/lib/comgr/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCPACK_GENERATOR=DEB -DCMAKE_PREFIX_PATH="/opt/rocm-5.0.0/llvm/;/root/ROCm-Device-Libs/build" ..
RUN make
RUN make package
RUN dpkg -i *.deb

ADD target.lst /opt/rocm-5.0.0/bin/
RUN apt install -y rocminfo


WORKDIR /root
RUN mkdir -p /root/hipamd/build
WORKDIR hipamd/build
# fix invalid cpack generator string
# RUN sed -i s/TGZ\:DEB/TGZ\;DEB/g ../packaging/CMakeLists.txt

RUN cmake -DCMAKE_CXX_COMPILER=/opt/rocm-5.0.0/bin/amdclang++ -DCMAKE_C_COMPILER=/opt/rocm-5.0.0/bin/amdclang -DHIP_COMMON_DIR=/root/hip -DAMD_OPENCL_PATH=/root/ROCm-OpenCL-Runtime -DROCCLR_PATH=/root/ROCclr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH=/opt/rocm-5.0.0/llvm/lib/cmake -DCMAKE_INSTALL_PREFIX=/opt/rocm-5.0.0 ..
RUN make -j8
RUN make package
RUN rm hip-runtime-nvidia*
RUN dpkg -i *.deb

# install all the rest via packages
RUN apt install -y rocm-dev rocm-libs

WORKDIR /root
