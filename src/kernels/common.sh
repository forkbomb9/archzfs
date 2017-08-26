# For build.sh
mode_name="common"
mode_desc="Select and use the packages that are common between all kernels"

# version
pkgrel="2"

header="\
# Maintainer: Jesus Alvarez <jeezusjr at gmail dot com>
#
# This PKGBUILD was generated by the archzfs build scripts located at
#
# http://github.com/archzfs/archzfs
#
#"

update_common_pkgbuilds() {
    pkg_list=("spl-utils-common" "zfs-utils-common")
    archzfs_package_group="archzfs-linux"
    spl_pkgver=${zol_version}
    zfs_pkgver=${zol_version}
    spl_pkgrel=${pkgrel}
    zfs_pkgrel=${pkgrel}
    spl_utils_conflicts="'spl-utils-common-git' 'spl-utils-linux-git' 'spl-utils-linux' 'spl-utils-linux-lts' 'spl-utils-linux-lts-git'"
    zfs_utils_conflicts="'zfs-utils-common-git' 'zfs-utils-linux-git' 'zfs-utils-linux' 'zfs-utils-linux-lts' 'zfs-utils-linux-lts-git'"
    spl_utils_pkgname="spl-utils-common"
    zfs_utils_pkgname="zfs-utils-common"
    # Paths are relative to build.sh
    spl_utils_pkgbuild_path="packages/${kernel_name}/${spl_utils_pkgname}"
    zfs_utils_pkgbuild_path="packages/${kernel_name}/${zfs_utils_pkgname}"
    spl_src_target="https://github.com/zfsonlinux/zfs/releases/download/zfs-${zol_version}/spl-${zol_version}.tar.gz"
    zfs_src_target="https://github.com/zfsonlinux/zfs/releases/download/zfs-${zol_version}/zfs-${zol_version}.tar.gz"
    spl_workdir="\${srcdir}/spl-${zol_version}"
    zfs_workdir="\${srcdir}/zfs-${zol_version}"
    spl_utils_replaces='replaces=("spl-utils-linux", "spl-utils-linux-lts")'
    zfs_utils_replaces='replaces=("zfs-utils-linux", "zfs-utils-linux-lts")'
}
