#!/usr/bin/env expect
exec sh -c "exec cat out/openruyi-base.* out/openruyi-linux-modules-* > initramfs.img"

proc abort {} {
  send_error "Timeout!"
  exit 1
}

set timeout 30

spawn sh -c {
  exec qemu-system-riscv64 \
    -nographic \
    -M virt -m 4G -cpu rva23s64 \
    -device virtio-gpu-pci \
    -kernel out/openruyi-linux-core-* \
    -initrd initramfs.img
}

expect {
  timeout abort
  "Run /init as init process"
}

expect {
  timeout abort
  "Welcome to openRuyi"
}

expect {
  timeout abort
  "virtio-gpu-pci" {
    sleep 1
    send "\n"
  }
}

expect {
  timeout abort
  "# " { send "\n" }
}

expect {
  timeout abort
  "# " { send "lsmod\n" }
}

expect {
  timeout abort
  "virtio_gpu"
}

expect {
  timeout abort
  "# " { send "poweroff\n" }
}

expect {
  timeout abort
  "Power down"
}

interact
