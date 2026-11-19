#!/bin/bash
set -e

# TITAN-X Linux Build Script
echo "Starting TITAN-X Firmware and Linux Kernel Build..."

export CROSS_COMPILE=riscv64-unknown-elf-
export ARCH=riscv

# Check dependencies
if ! command -v dtc &> /dev/null; then
    echo "Error: Device Tree Compiler (dtc) is not installed."
    echo "Please run: sudo apt-get install device-tree-compiler"
    exit 1
fi

if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
    echo "Error: RISC-V cross compiler not found in PATH."
    exit 1
fi

# 1. Compile Device Tree
echo "Compiling Device Tree..."
dtc -I dts -O dtb -o titan_x.dtb titan_x.dts

# 2. Build OpenSBI
if [ ! -d "opensbi" ]; then
    echo "Cloning OpenSBI..."
    git clone https://github.com/riscv-software-src/opensbi.git
    cd opensbi
    git checkout v1.2
    cd ..
fi
cd opensbi
echo "Compiling OpenSBI for TITAN-X..."
make PLATFORM=generic PLATFORM_RISCV_ISA=rv64ima_zicsr_zifencei PLATFORM_RISCV_ABI=lp64 FW_FDT_PATH=../titan_x.dtb FW_PIC=n
cp build/platform/generic/firmware/fw_payload.elf ../titan_x_fw.elf
cp build/platform/generic/firmware/fw_payload.bin ../titan_x_fw.bin
cd ..

# 3. (Optional) Clone and Build Linux Kernel
# If user wants full linux, we download minimal buildroot or linux kernel
echo "To build Linux Kernel, we recommend using Buildroot to generate vmlinux and initramfs."
echo "For now, the OpenSBI payload (titan_x_fw.elf) is ready to boot in Verilator."

echo "Build complete."
