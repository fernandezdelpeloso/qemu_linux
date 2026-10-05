#!/usr/bin/env bash

set -euo pipefail


# -------------------------------------------------------------------
# Working-directory policy
# -------------------------------------------------------------------

WORKDIR="$(pwd -P)"


# -------------------------------------------------------------------
# Kernel package
# -------------------------------------------------------------------

KERNEL_VERSION="7.0.0-070000-generic"

KERNEL_DEB="linux-image-unsigned-7.0.0-070000-generic_7.0.0-070000.202604122140_amd64.deb"

KERNEL_BASE_URL="https://kernel.ubuntu.com/mainline/v7.0/amd64"

KERNEL_URL="$KERNEL_BASE_URL/$KERNEL_DEB"

KERNEL_CHECKSUMS_URL="$KERNEL_BASE_URL/CHECKSUMS"

KERNEL_FILE="$WORKDIR/extracted_kernel_folder/boot/vmlinuz-$KERNEL_VERSION"


echo "**********************************************************************"
echo "Downloading kernel package..."
echo "**********************************************************************"

wget \
    --no-hsts \
    -c \
    -O "$WORKDIR/$KERNEL_DEB" \
    "$KERNEL_URL"


# -------------------------------------------------------------------
# Verify kernel package
# -------------------------------------------------------------------

echo "**********************************************************************"
echo "Verifying kernel package..."
echo "**********************************************************************"

wget \
    --no-hsts \
    -O "$WORKDIR/kernel-CHECKSUMS" \
    "$KERNEL_CHECKSUMS_URL"

(
    cd "$WORKDIR"

    grep " $KERNEL_DEB\$" kernel-CHECKSUMS |
        sha256sum --check -
)


# -------------------------------------------------------------------
# Extract kernel
# -------------------------------------------------------------------

echo "**********************************************************************"
echo "Extracting kernel image..."
echo "**********************************************************************"

rm -rf "$WORKDIR/extracted_kernel_folder"

mkdir -p "$WORKDIR/extracted_kernel_folder"

dpkg-deb \
    -x \
    "$WORKDIR/$KERNEL_DEB" \
    "$WORKDIR/extracted_kernel_folder"


if [[ ! -f "$KERNEL_FILE" ]]; then
    echo "Error: extracted kernel image was not found:" >&2
    echo "$KERNEL_FILE" >&2
    exit 1
fi


# -------------------------------------------------------------------
# Prepare minimal root filesystem
# -------------------------------------------------------------------

echo "**********************************************************************"
echo "Preparing minimal root filesystem..."
echo "**********************************************************************"

rm -rf \
    "$WORKDIR/rootfs" \
    "$WORKDIR/busybox-extracted" \
    "$WORKDIR/initramfs.cpio.gz"

mkdir -p \
    "$WORKDIR/rootfs/bin" \
    "$WORKDIR/rootfs/dev" \
    "$WORKDIR/rootfs/proc" \
    "$WORKDIR/rootfs/sys"


# -------------------------------------------------------------------
# BusyBox
# -------------------------------------------------------------------

BUSYBOX_DEB="busybox-static_1.36.1-6ubuntu3.1_amd64.deb"

BUSYBOX_URL="https://archive.ubuntu.com/ubuntu/pool/main/b/busybox/$BUSYBOX_DEB"

BUSYBOX_SHA256="944b2728f53ceb3916cec2c962873c9951e612408099601751db2a0a5d81e0ed"


echo "**********************************************************************"
echo "Downloading static BusyBox..."
echo "**********************************************************************"

wget \
    --no-hsts \
    -c \
    -O "$WORKDIR/$BUSYBOX_DEB" \
    "$BUSYBOX_URL"


# -------------------------------------------------------------------
# Verify BusyBox package
# -------------------------------------------------------------------

echo "**********************************************************************"
echo "Verifying BusyBox package..."
echo "**********************************************************************"

(
    cd "$WORKDIR"

    echo "$BUSYBOX_SHA256  $BUSYBOX_DEB" |
        sha256sum --check -
)


# -------------------------------------------------------------------
# Extract BusyBox
# -------------------------------------------------------------------

mkdir -p "$WORKDIR/busybox-extracted"

dpkg-deb \
    -x \
    "$WORKDIR/$BUSYBOX_DEB" \
    "$WORKDIR/busybox-extracted"

cp \
    "$WORKDIR/busybox-extracted/usr/bin/busybox" \
    "$WORKDIR/rootfs/bin/busybox"


# -------------------------------------------------------------------
# Minimal BusyBox applet links
# -------------------------------------------------------------------

ln -s busybox "$WORKDIR/rootfs/bin/sh"


# -------------------------------------------------------------------
# /init
#
# /init remains PID 1.
#
# The interactive shell runs as a child process. Therefore typing
# "exit" terminates only the child shell and returns control to /init,
# which can then shut the virtual machine down cleanly.
# -------------------------------------------------------------------

cat > "$WORKDIR/rootfs/init" <<'EOF'
#!/bin/busybox sh

/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev

echo
echo "hello world"
echo
echo "Type 'exit' to shut down the virtual machine."
echo

# Run a child shell. Do NOT use exec here: /init must remain PID 1.
/bin/busybox sh

echo
echo "Shutting down..."
echo

/bin/busybox sync
/bin/busybox poweroff -f

# Safety fallback: PID 1 must never exit.
exec /bin/busybox sleep 2147483647
EOF

chmod +x "$WORKDIR/rootfs/init"


# -------------------------------------------------------------------
# Build initramfs
# -------------------------------------------------------------------

echo "**********************************************************************"
echo "Building compressed initramfs archive..."
echo "**********************************************************************"

(
    cd "$WORKDIR/rootfs"

    find . -print0 |
        cpio \
            --null \
            --create \
            --format=newc \
            --owner=0:0 |
        gzip -9
) > "$WORKDIR/initramfs.cpio.gz"


# -------------------------------------------------------------------
# Build summary
# -------------------------------------------------------------------

echo
echo "**********************************************************************"
echo "Build complete"
echo "**********************************************************************"

ls -lh "$KERNEL_FILE"
ls -lh "$WORKDIR/initramfs.cpio.gz"

echo


# -------------------------------------------------------------------
# Launch QEMU
# -------------------------------------------------------------------

echo "**********************************************************************"
echo "Launching QEMU"
echo "**********************************************************************"
echo

qemu-system-x86_64 \
    -m 512 \
    -kernel "$KERNEL_FILE" \
    -initrd "$WORKDIR/initramfs.cpio.gz" \
    -append "console=ttyS0 quiet loglevel=3" \
    -nographic
