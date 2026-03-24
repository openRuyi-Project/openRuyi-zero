FROM fedora
RUN dnf install -y cpio dnf5 kmod expect qemu-system-riscv
