# openRuyi Zero

*A minimal openRuyi initramfs, with zero unneeded services*

```
[root@openruyi /]# ps -ef | grep -v '\]$'
PID   USER     TIME  COMMAND
    1 root      0:02 busybox init
   89 root      0:00 mdevd -C -O 4
   90 root      0:00 -/bin/sh
   91 root      0:00 busybox init
  140 root      0:00 ps -ef
  141 root      0:00 grep -v \]$
```

## Features

The openRuyi Zero edition is created to facilitate pre-Silicon SoC bringup. With the constraints of FPGA-based CPU and SoC emulation in mind, openRuyi Zero was made with the following features:

- Pre-built initramfs distribution for easy bootup
- Bring-your-own-kernel workflow support with support for kernel modules
- Busybox init, with zero unneeded services
- Runs as few programs as possible, giving you a shell as fast as possible
  - mdevd + libudev-zero instead of Systemd udev
- Minimal Weston Wayland environment for graphics stack validation

## Usage

You can start openRuyi initramfs by providing it to your kernel through Devicetree or UEFI. This will depend on your device's boot process and thus is not described here.

Here's an example command for booting through QEMU with basic hardware emulation support for both CLI and GUI.

```sh
qemu-system-riscv64 \
  -M virt -smp 1 -m 4G -cpu rva23s64 \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-device,rng=rng0 \
  -device virtio-net-device,netdev=usernet \
  -netdev user,id=usernet,hostfwd=tcp::12055-:22 \
  -display sdl,gl=on -device virtio-gpu-gl-pci \
  -device qemu-xhci -usb -device usb-kbd -device usb-mouse \
  -serial mon:stdio \
  -kernel {path-to-your-kernel} \
  -initrd /path/to/openruyi-base.cpio.gz
```

If kernel modules are required, read on.

### Using the pre-build kernel and module addons

You can use openRuyi-provided kernels and module addons. The release files with openRuyi kernels require module addons for hardware support such as USB or GPU.

As an example, to use the following kernel and module addon:

```
openruyi-linux-core-vmlinuz-6.19.8-16.1.or
openruyi-linux-modules-6.19.8-16.1.or.cpio
```

You can concat the `.cpio` into the base initramfs to create the final initramfs, with a command like (replacing `/path/to/...` with actual paths):

```console
$ cat /path/to/openruyi-base.cpio.gz /path/to/openruyi-linux-modules-6.19.8-16.1.or.cpio > final-initramfs.img
```

And use `final-initramfs.img` instead for booting. As an example, for QEMU, replace the final command line arguments with:

```
...
  -kernel /path/to/openruyi-linux-core-vmlinuz-6.19.8-16.1.or \
  -initrd final-initramfs.img
```

### Using custom kernels and module addons

(In the following command examples, replace `"${makeFlags[@]}"` with the arguments required to build your kernel.)

If you use your own kernel that requires modules, it is easy to create a module addon based on that. Within the kernel source tree, after building the kernel and modules, use this command to install modules into the `modroot/` directory:

```console
$ make "${makeFlags[@]}" INSTALL_MOD_PATH="$(pwd)/modroot" modules_install
```

If `depmod` was disabled in the previous step, or more modules are added later, it may be necessary to run `depmod` to regenerate module dependency files:

```console
$ depmod -b modroot/ "$(make "${makeFlags[@]}" -s kernelrelease)"
```

After that, pack up the result into an addon:

```console
$ ( cd modroot && find -print0 | cpio -0 -R0:0 -o --format=newc > ../modules.cpio )
```

Finally, concatenate the base initramfs with your kernel module addon to create the final initramfs (replace `/path/to/...` with the actual path):

```console
$ cat /path/to/openruyi-base.cpio.gz modules.cpio > final-initramfs.img
```

And use `final-initramfs.img` instead for booting. As an example, for QEMU, replace the final command line arguments with (replace `/path/to/...` with the actual path):

```
...
  -kernel /path/to/your-kernel/Image \
  -initrd final-initramfs.img
```

### Other kinds of addons

You can create other kinds of addons using a similar process. For example, some devices may require extra firmware files in `/lib/firmware` to function. You can create a `firmware.cpio` addon with commands such as:

```console
$ install -Dm 0644 /path/to/lib/firmware/foo/bar.bin fwroot/lib/firmware/foo/bar.bin
$ ( cd fwroot && find -print0 | cpio -0 -R0:0 -o --format=newc > ../firmware.cpio )
```

## Usage after boot

### Basic usage

Since the initramfs contains a mostly complete system, it is larger than a typical initramfs and will take longer to boot with. Depending on your FPGA emulation speed, it may take a few minutes to fully unpack the initramfs.

On successful boot, you will see messages such as:

```
[   90.019455] Run /init as init process
Welcome to openRuyi-validation

Please press Enter to activate this console.
```

Pressing Enter here on the terminal should bring up a root shell.

Note that kernel informational messages may print after this message and make it hard to find. If you don't see this message but it seems that the kernel has booted, try pressing Enter anyway.

### Graphics

You can start a kmscube demo with the command:

```console
$ kmscube
```

Note that on early boot, you may need to wait for the graphics kernel drivers to load first.

Alternatively, you can start a Weston desktop using:

```console
$ seatd-launch -- weston -S wayland-0
```

This brings up a minimal Weston-based Wayland desktop. Clicking the top left terminal icon brings up weston-terminal. With it, you can run some demos, such as:

```console
$ eglgears_wayland
```

## Known issues

### Error messages `libudev.so.1: no version information available`

This message may show up when running Weston:

```
weston: /lib64/lp64d/libudev.so.1: no version information available (required by ...)
```

This is expected, as we have replaced Systemd libudev with libudev-zero, and can be safely ignored.

### Font rendering problems

Font rendering may look unexpected.

This is expected, as many fonts and font configurations were omitted to minimize the initramfs size.

## Building

Under the repository directory, run:

```
# ./build.sh
```

The build script requires the following dependencies:

- bash
- coreutils
- dnf5
- rpm
- cpio

In addition, binfmt_misc emulation for Linux on 64-bit RISC-V must be available with something like qemu-user-static-riscv, depending on your distro.

The script will download and install packages from openRuyi to prepare the base initramfs file, as well as kernel and module addons for the openRuyi `linux` and `linux-lts` packages. The output will be stored in the `out/` directory.

The build script requires running as root. Therefore, it is recommended to run the build in a container for improved security and isolation. (Note that Linux kernel 6.7 and later supports isolating binfmt_misc inside containers.)

### Customization

The configurations in `config.sh` allows for customization of the build. Please see comments in `config.sh` for more details.
