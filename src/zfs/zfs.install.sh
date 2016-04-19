#!/bin/bash

cat << EOF > ${AZB_ZFS_PKGBUILD_PATH}/zfs.install
post_install() {
    check_initramfs
}

post_remove() {
    check_initramfs 'remove'
}

post_upgrade() {
    check_initramfs
}

check_initramfs() {
    echo ">>> Updating ZFS module dependencies"
    # depmod -v ${AZB_KERNEL_MOD_PATH}
    depmod -a -v
    MK_CONF=\$(grep -v '#' /etc/mkinitcpio.conf | grep zfs >/dev/null; echo \$?);
    if [[ \${MK_CONF} == '0' ]]; then
        if [[ \$1 == 'remove' ]]; then
            echo '>>> The ZFS packages have been removed, but "zfs" remains in the "hooks"'
            echo '>>> list in mkinitcpio.conf! You will need to remove "zfs" from the '
            echo '>>> "hooks" list and then regenerate the initial ramdisk.'
        else
            echo ">>> Generating initial ramdisk, using mkinitcpio. Please wait..."
            mkinitcpio -p linux
        fi
    fi
}
EOF
