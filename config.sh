# Architecture to use
arch=riscv64

# Linux packages to build kernel and module addon for
linux_packages=(linux linux-lts)

# Packages to install without dependencies early on
packages_early=(
  bash coreutils
)

# Packages to install without dependencies early on
force_packages_early=(
  ca-certificates ca-certificates-mozilla
)

# Packages to install
packages=(
  busybox kmod mdevd util-linux
  libudev-zero
  weston seatd mesa-gl mesa-dril
  kmscube
)

# Packages to install without dependencies
force_packages=(
  mesa-demos libdecor dbus
)

# Packages to erase after installing
erase_packages=(
  systemd ca-certificates ca-certificates-mozilla
)

# Packages to erase, ignoring reverse dependencies
force_erase_packages=(
  icu4c
)
