Exercise 1: Bootable Linux via QEMU

In order to determine the minimum setup for the script to run, I installed a VM with Ubuntu 24.04.5 LTS AMD64
as host and the option “Third-party software for graphics and wi-fi hardware” enabled. After updating
the system with “sudo apt update” followed by “sudo apt upgrade”, the only package that had to be installed
was qemu‑system by simply running “sudo apt install qemu-system”.

The script works by downloading a publicly available pre-built kernel. I chose
the pre-built Ubuntu AMD64 Linux kernel version 7.0 because this was the kernel version included in
the recommended distribution for the exercise.

The script satisfies all exercise requirements.

I was not able to create an image loadable through firmware because of the given time frame limitation.
