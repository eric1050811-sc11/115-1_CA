# Lab0 Report

## GTKwave

```bash
sudo apt install gtkwave
```

## Install RISC-V Toolchain

```bash
cd
wget https://github.com/nycu-arclab/ca-devtools/releases/download/linux_2026/riscv32-unknown-elf-gcc-14.2.0-linux.tar.gz
sudo tar -xvzf riscv32-unknown-elf-gcc-14.2.0-linux.tar.gz -C /opt
echo "export PATH=$PATH:/opt/riscv/bin" >> ~/.bashrc
source .bashrc
```

## Install iverilog

```bash
cd
wget https://github.com/nycu-arclab/ca-devtools/releases/download/linux_2026/iverilog-12-linux.tar.gz
sudo tar -xvzf iverilog-12-linux.tar.gz -C /
echo "export PATH=$PATH:/opt/iverilog-12/bin" >> ~/.bashrc
source ~/.bashrc
```
