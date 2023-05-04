#!/bin/bash
sed -i '$d' /autoinstall.yaml
xda=$(lsblk -dn -o NAME | grep -E 'nvme0n1|.da')
# 是用 size 寻找分区，number 没什么用
# https://curtin.readthedocs.io/en/latest/topics/storage.html
size_os=$(lsblk -bn -o SIZE /dev/disk/by-label/os)

if parted /dev/sda print | grep '^Partition Table' | grep gpt; then
  # parted 3.1 on centos7 bug
  # https://documentation.suse.com/zh-cn/sles/15/html/SLES-all/cha-expert-partitioner.html#sec-expert-partitioner-tables-gpt
  parted /dev/$xda -s 'set 2 msftdata off' # os
  parted /dev/$xda -s 'set 3 msftdata off' # installer

  # efi
  if [ -e /dev/disk/by-label/efi ]; then
    size_efi=$(lsblk -bn -o SIZE /dev/disk/by-label/efi)
    cat <<EOF >>/autoinstall.yaml
storage:
  config:
    # disk
    - ptable: gpt
      path: /dev/$xda
      preserve: true
      type: disk
      id: disk-xda
    # efi 分区
    - device: disk-xda
      size: $size_efi
      number: 1
      preserve: true
      grub_device: true
      type: partition
      id: partition-efi
    - fstype: fat32
      volume: partition-efi
      type: format
      id: format-efi
    # os 分区
    - device: disk-xda
      size: $size_os
      number: 2
      preserve: true
      type: partition
      id: partition-os
    - fstype: ext4
      volume: partition-os
      type: format
      id: format-os
    # mount
    - path: /
      device: format-os
      type: mount
      id: mount-os
    - path: /boot/efi
      device: format-efi
      type: mount
      id: mount-efi
EOF
  else
    # bios 2t
    size_biosboot=$(parted /dev/$xda unit b print | grep bios_grub | awk '{print $4}' | sed 's/B$//')
    cat <<EOF >>/autoinstall.yaml
storage:
  config:
    # disk
    - ptable: gpt
      path: /dev/$xda
      preserve: true
      grub_device: true
      type: disk
      id: disk-xda
    # biosboot 分区
    - device: disk-xda
      size: $size_biosboot
      number: 1
      preserve: true
      type: partition
      id: partition-biosboot
    # os 分区
    - device: disk-xda
      size: $size_os
      number: 2
      preserve: true
      type: partition
      id: partition-os
    - fstype: ext4
      volume: partition-os
      type: format
      id: format-os
    # mount
    - path: /
      device: format-os
      type: mount
      id: mount-os
EOF
  fi
else
  # bios
  cat <<EOF >>/autoinstall.yaml
storage:
  config:
    # disk
    - ptable: msdos
      path: /dev/$xda
      preserve: true
      grub_device: true
      type: disk
      id: disk-xda
    # os 分区
    - device: disk-xda
      size: $size_os
      number: 1
      preserve: true
      type: partition
      id: partition-os
    - fstype: ext4
      volume: partition-os
      type: format
      id: format-os
    # mount
    - path: /
      device: format-os
      type: mount
      id: mount-os
EOF
fi
echo ... >>/autoinstall.yaml