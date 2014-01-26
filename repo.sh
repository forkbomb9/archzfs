#!/bin/bash

#
# repo.sh adds the archzfs packages to a specified repository.
#

source ./lib.sh
source ./conf.sh

set -e

trap 'trap_abort' INT QUIT TERM HUP
trap 'trap_exit' EXIT

DRY_RUN=0   # Show commands only. Don't do anything.
AZB_REPO=""     # The destination repo for the packages

msg "repo.sh started!"

usage() {
	echo "repo.sh - Adds the compiled packages to the archzfs repo."
    echo
	echo "Usage: repo.sh [options] [repo] [package [...]]"
    echo
    echo "Options:"
    echo
    echo "    -h:    Show help information."
    echo
    echo "    -n:    Dryrun; Output commands, but don't do anything."
    echo
    echo "    -d:    Show debug info."
    echo
    echo "Example Usage:"
    echo
    echo "    1) Adding packages in the current directory to a local repo."
    echo
    echo "       repm core"
    echo
    echo "    2) Show output commands and debug info."
    echo
    echo "       repm core -n -d"
    echo
    echo "    3) Adding a specific package to a repository."
    echo
    echo "       repm core package.tar.xz"
    echo
    echo "    4) Adding a multiple packages to a repository."
    echo
    echo "       repm core *.tar.xz"
}

ARGS=("$@")
for (( a = 0; a < $#; a++ )); do
    if [[ ${ARGS[$a]} == "core" ]]; then
        AZB_REPO="demz-repo-core"
    elif [[ ${ARGS[$a]} == "community" ]]; then
        AZB_REPO="demz-repo-community"
    elif [[ ${ARGS[$a]} == "testing" ]]; then
        AZB_REPO="demz-repo-testing"
    elif [[ ${ARGS[$a]} == "archiso" ]]; then
        AZB_REPO="demz-repo-archiso"
    elif [[ ${ARGS[$a]} == "-h" ]]; then
        usage;
        exit 0;
    elif [[ ${ARGS[$a]} == "-n" ]]; then
        DRY_RUN=1
    elif [[ ${ARGS[$a]} == "-d" ]]; then
        DEBUG=1
    fi
done

if [ $# -lt 1 ]; then
    usage;
    exit 0;
fi

if [[ $AZB_REPO == "" ]]; then
    error "No destination repo specified!"
    exit 1
fi

# The abs path to the repo
AZB_REPO_TARGET=$AZB_REPO_BASEPATH/$AZB_REPO

# The abs path to the package source directory in the repo
AZB_SOURCE_TARGET="$AZB_REPO_TARGET/sources/"

debug "DEBUG: DRY_RUN: "$DRY_RUN
debug "DEBUG: AZB_REPO: "$AZB_REPO
debug "DEBUG: AZB_REPO_TARGET: $AZB_REPO_TARGET"
debug "DEBUG: AZB_SOURCE_TARGET: $AZB_SOURCE_TARGET"

# A list of packages to install. Pulled from the command line.
pkgs=()

# Extract any packages from the arguments passed to the script
for arg in "$@"; do
    if [[ $arg =~ pkg.tar.xz$ ]]; then
        pkgs+=("${pkgs[@]}" $arg)
    fi
done

# Get the local packages if no packages were passed to the script
if [[ "${#pkgs[@]}" -eq 0 ]]; then
    for pkg in $(find . -iname "*.pkg.tar.xz"); do
        debug "DEBUG: Found package: $pkg"
        pkgs+=($pkg)
    done
fi

for pkg in ${pkgs[@]}; do
    debug "DEBUG: PKG: $pkg"
done

if [[ $AZB_REPO != "" ]]; then

    msg "Creating a list of packages to add..."
    # A list of packages to add. The strings are in the form of
    # "name;pkg.tar.xz;repo_path". There must be no spaces.
    pkg_list=()

    # Add packages to the pkg_list
    for pkg in ${pkgs[@]}; do
        arch=$(pacman -Qip $pkg | grep "Architecture" | cut -d : -f 2 | tr -d ' ')
        name=$(pacman -Qip $pkg | grep "Name" | cut -d : -f 2 | tr -d ' ')
        vers=$(pacman -Qip $pkg | grep "Version" | cut -d : -f 2 | tr -d ' ')
        debug "DEBUG: Found package: $name, $arch, $vers"
        if [[ $vers != $AZB_FULL_VERSION ]]; then
            continue
        fi
        if [[ $arch == "any" ]]; then
            repos=`realpath $AZB_REPO_TARGET/{x86_64,i686}`
            for repo in $repos; do
                debug "DEBUG: Using: $name;$vers;$pkg;$repo"
                pkg_list+=("$name;$vers;$pkg;$repo")
            done
            continue
        fi
        debug "DEBUG: Using: $name;$vers;$pkg;$AZB_REPO_TARGET/$arch"
        pkg_list+=("$name;$vers;$pkg;$AZB_REPO_TARGET/$arch")
    done

    if [[ ${#pkg_list[@]} == 0 ]]; then
        error "No packages to process!"
        exit 1
    fi

    pkg_mv_list=()
    pkg_cp_list=()
    pkg_add_list=()
    src_rm_list=()
    src_cp_list=()

    for ipkg in ${pkg_list[@]}; do
        IFS=';' read -a pkgopt <<< "$ipkg"

        name="${pkgopt[0]}"
        vers="${pkgopt[1]}"
        pbin="${pkgopt[2]}"
        repo="${pkgopt[3]}"

        msg2 "Processing $pbin to $repo"
        [[ ! -d $repo ]] && run_cmd "mkdir -p $repo"

        # Move the old packages to backup
        for x in $(find $repo -type f -iname "${name}*.pkg.tar.xz"); do
            ename=$(pacman -Qip $x | grep "Name" | cut -d : -f 2 | tr -d ' ')
            evers=$(pacman -Qip $x | grep "Version" | cut -d : -f 2 | tr -d ' ')
            debug "DEBUG: Found Old Package: $ename, Version: $evers"
            if [[ $ename == $name && $evers != $vers ]]; then
                # The '*' globs the signatures
                debug "DEBUG: Added $repo/$ename-${evers}* to move list"
                pkg_mv_list+=("$repo/$ename-${evers}*")
            fi
        done

        pkg_cp_list+=("$pbin*;$repo")

        bname=$(basename $pbin)
        pkg_add_list+=("$repo/$bname;$repo")

        # Copy the sources to the source target
        [[ ! -d $AZB_SOURCE_TARGET ]] && run_cmd "mkdir -p $AZB_SOURCE_TARGET"

        # If there is zfs and zfs-utils in the directory, the glob will get
        # both zfs and zfs-utils when globbing zfs*, therefore we have to check
        # each file to see if it is the one we want.
        for file in $(find -L $AZB_SOURCE_TARGET -iname "${name}*.src.tar.gz" 2>/dev/null); do
            src_name=$(tar -O -xzvf $file $name/PKGBUILD 2> /dev/null | grep "pkgname" | cut -d \" -f 2)
            debug "DEBUG: Source name: $src_name, File: $file"
            if [[ $src_name == $name ]]; then
                src_rm_list+=("$file")
            fi
        done
        src_cp_list+=("./$name/$name-${vers}.src.tar.gz")
    done

    echo
    echo

    run_cmd "mv ${pkg_mv_list[*]} $AZB_REPO_BASEPATH/backup/"

    for arch in "i686" "x86_64"; do
        cp_list=""
        ra_list=""
        repo=""
        for pkg in "${pkg_cp_list[@]}"; do
            debug "DEBUG pkg_cp_list: $pkg"
            if [[ "$pkg" == *$arch* ]]; then
                cp_list="$cp_list "$(echo "$pkg" | cut -d \; -f 1)
                repo=$(echo "$pkg" | cut -d \; -f 2)
                ra=$(echo "$pkg" | cut -d \; -f 1 | xargs basename)
                ra_list="$ra_list $repo/${ra%?}"
                debug "DEBUG: cp_list: $cp_list"
                debug "DEBUG: ra_list: $ra_list"
                debug "DEBUG: REPO: $repo"
            fi
        done
        echo
        echo
        run_cmd "cp $cp_list $repo/"
        echo
        echo
        run_cmd "repo-add -k $AZB_GPG_SIGN_KEY -s -v -f $repo/${AZB_REPO}.db.tar.xz $ra_list"
        if [[ $? -ne 0 ]]; then
            error "An error occurred adding the package to the repo!"
            exit 1
        fi
    done

    if [[ ${#src_rm_list[@]} -ne 0 ]]; then
        echo
        echo
        zlist=$(echo "${src_rm_list[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
        run_cmd "rm $zlist"
    fi

    echo
    echo

    nlist=$(echo "${src_cp_list[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    run_cmd "cp $nlist $AZB_SOURCE_TARGET"

fi
