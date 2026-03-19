#!/usr/bin/env bash

_main() {

set -e -x -u -o pipefail
shopt -s nullglob

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

# Linux packages to build kernel and module addon for
linux_packages=(linux linux-lts)

# Architecture to use
arch=riscv64

# DNF configuration
wd="$(pwd)"
dnf5args=(
  --assumeyes
  --forcearch="$arch"
  --best
  "--setopt=reposdir=$wd/reposdir"
  "--setopt=varsdir=$wd/dnftmp/varsdir"
  "--setopt=cachedir=$wd/dnftmp/cachedir"
  "--setopt=persistdir=$wd/root/var/lib/dnf"
  "--setopt=install_weak_deps=no"
  "--installroot=$wd/root"
)

# Utilities

die() {
  echo "$*" >&2
  exit 1
}

remkdir() {
  rm -rf "$1"
  mkdir -p "$1"
}

mkcpio() {
  ( cd "$1" ; find -print0 | cpio -o -0 -R +0:+0 --format=newc )
}

versionof() {
  [[ "$1" =~ "$2"-(.+)\.$arch\.rpm ]] || die "Unable to get version of $1"
  echo "${BASH_REMATCH[1]}"
}

forceinstall() {
  local rpms=()
  for id in "$@"; do
    rm -f "$id"-*.rpm
  done
  dnf5 download "${dnf5args[@]}" "$@"
  for id in "$@"; do
    rpms+=("$id"-*."$arch".rpm)
  done
  rpm --noscripts --nodeps --root "$wd/root/" --ignorearch -i "${rpms[@]}"
}

unpackrpm() {
  rpm2cpio "$1" | ( cd "$2" && cpio -idmv )
}

padinitramfs() {
  # Pad (possibly compressed) initramfs to multiple of four bytes for concatenation
  truncate -s $(( ("$(stat --format '%s' "$1")" + 3) & ~3 )) "$1"
}

# Main section starts here

outputs=()
remkdir out

# Rootfs without kernel-dependent stuff

remkdir root

dnf5 update "${dnf5args[@]}"
(( ${#packages_early[@]} )) && dnf5 install "${dnf5args[@]}" "${packages_early[@]}"
(( ${#force_packages_early[@]} )) && forceinstall "${force_packages_early[@]}"
(( ${#packages[@]} )) && dnf5 install "${dnf5args[@]}" "${packages[@]}"
(( ${#erase_packages[@]} )) && dnf5 remove "${dnf5args[@]}" "${erase_packages[@]}"
(( ${#force_packages[@]} )) && forceinstall "${force_packages[@]}"
(( ${#force_erase_packages[@]} )) && rpm --noscripts --nodeps --root "$wd/root/" -e "${force_erase_packages[@]}"

{
    mkcpio rootfs.extra
    mkcpio root
} | gzip -1 > out/openruyi-base.cpio.gz

padinitramfs out/openruyi-base.cpio.gz

outputs+=(out/openruyi-base.cpio.gz)

# Kernels and kernel modules

for linux in "${linux_packages[@]}"; do
  rm -f "$linux"-*.rpm
  dnf5 "${dnf5args[@]}" download "$linux"-core "$linux"-modules

  linux_core="$(echo "$linux"-core-*.rpm)"
  linux_modules="$(echo "$linux"-modules-*.rpm)"

  kernel_ver=$(versionof "$linux_core" "$linux"-core)

  if ! [[ "$kernel_ver" == "$(versionof "$linux_modules" "$linux"-modules)" ]]; then
    die "Version mismatch between $linux_core and $linux_modules"
  fi

  linux_core_out=out/openruyi-"$linux"-core-vmlinuz-"$kernel_ver"
  remkdir linux-core-install
  unpackrpm "$linux_core" linux-core-install/
  cp linux-core-install/usr/lib/modules/*/vmlinuz "$linux_core_out"
  outputs+=("$linux_core_out")

  linux_modules_out=out/openruyi-"$linux"-modules-"$kernel_ver".cpio
  remkdir linux-modules-install
  unpackrpm "$linux_modules" linux-modules-install/
  depmod -b linux-modules-install/usr "$kernel_ver"
  mkcpio linux-modules-install > "$linux_modules_out"
  padinitramfs "$linux_modules_out"
  outputs+=("$linux_modules_out")
done

set +x

echo >&2
echo Done. Outputs: >&2
ls -lhU "${outputs[@]}" >&2

}

_main
