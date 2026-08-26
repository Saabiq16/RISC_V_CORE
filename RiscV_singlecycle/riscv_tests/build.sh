#!/bin/bash

SRC=$1
ELF="test.elf"
OBJ="test.o"
HEX="/media/sf_test_hex/instructions.hex"

if [ -z "$SRC" ]; then
    echo "Usage: ./build.sh <test.s>"
    exit 1
fi

echo "==> Assembling $SRC"

riscv32-unknown-elf-as \
    -march=rv32im \
    -mabi=ilp32 \
    "$SRC" \
    -o "$OBJ"

if [ $? -ne 0 ]; then
    echo "ERROR: Assembly failed"
    exit 1
fi

echo "==> Linking at address 0x0"

riscv32-unknown-elf-ld \
    -Ttext=0x0 \
    "$OBJ" \
    -o "$ELF"

if [ $? -ne 0 ]; then
    echo "ERROR: Linking failed"
    exit 1
fi

echo "==> Generating 32-bit instruction hex"

riscv32-unknown-elf-objcopy \
    -O verilog \
    --verilog-data-width=4 \
    "$ELF" \
    "$HEX"

if [ $? -ne 0 ]; then
    echo "ERROR: HEX generation failed"
    exit 1
fi

echo
echo "SUCCESS!"
echo "Generated:"
echo "$HEX"
