#!/bin/bash
# Build and run libhugetlbfs tests.One needs to run with a kernel that supports huge pages

#加载外部环境
. ../../../../utils/sh-test-lib
. ../../../../utils/sys_info.sh
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TMP_LOG="${OUTPUT}/tmp_log.txt"
TEST_PASS_LOG="${OUTPUT}/test_pass_log.txt"
TEST_FAIL_LOG="${OUTPUT}/test_fail_log.txt"
TEST_SKIP_LOG="${OUTPUT}/test_skip_log.txt"
CWD=""

WORD_SIZE="64"
VERSION="2.20"

usage() {
    echo "Usage: $0 [-b <4|64>] [-s <true>] [-v <libhugetlbfs-version>]" 1>&2
    exit 1
}

while getopts "b:s:v:" o; do
  case "$o" in
    b) WORD_SIZE="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    v) VERSION="${OPTARG}" ;;
    *) usage ;;
  esac
done

parse_output() {
    # Avoid results summary lines start with "*"
    sed -i -e 's/\//-/g' "${TMP_LOG}"
    # shellcheck disable=SC2063
    grep -v "*"  "${TMP_LOG}" | tee -a "${RESULT_LOG}"
    # Parse each type of results
    egrep "PASS" "${RESULT_LOG}" | tee -a "${TEST_PASS_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_PASS_LOG}"
    sed -i -e 's/(//g' "${TEST_PASS_LOG}"
    sed -i -e 's/)://g' "${TEST_PASS_LOG}"
    sed -i -e 's/://g' "${TEST_PASS_LOG}"
    awk '{for (i=1; i<NF-1; i++) printf $i "-"; print $i " " $NF}' "${TEST_PASS_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
    sed -i -e 's/PASS/pass/g' "${RESULT_FILE}"

    egrep "FAIL" "${RESULT_LOG}" | cut -d: -f 1-2 2>&1 | tee -a "${TEST_FAIL_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_FAIL_LOG}"
    sed -i -e 's/(//g' "${TEST_FAIL_LOG}"
    sed -i -e 's/)//g' "${TEST_FAIL_LOG}"
    sed -i -e 's/://g' "${TEST_FAIL_LOG}"
    awk '{for (i=1; i<NF; i++) printf $i "-"; print $i " " "fail"}' "${TEST_FAIL_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

    egrep "SKIP" "${RESULT_LOG}" | cut -d: -f 1-2 2>&1 | tee -a "${TEST_SKIP_LOG}"
    egrep "Bad configuration" "${RESULT_LOG}" | cut -d: -f 1-2 2>&1 | tee -a "${TEST_SKIP_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_SKIP_LOG}"
    sed -i -e 's/(//g' "${TEST_SKIP_LOG}"
    sed -i -e 's/)//g' "${TEST_SKIP_LOG}"
    sed -i -e 's/://g' "${TEST_SKIP_LOG}"
    awk '{for (i=1; i<NF; i++) printf $i "-"; print $i " " "skip"}' "${TEST_SKIP_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

    # Replace "=" with "_" in test case names
    sed -i -e 's/=/_/g' "${RESULT_FILE}"
    # Clean up
    rm -rf "${TMP_LOG}" "${RESULT_LOG}" "${TEST_PASS_LOG}" "${TEST_FAIL_LOG}" "${TEST_SKIP_LOG}"

}

libhugetlbfs_setup() {
    mount_point="/mnt/hugetlb/"
    # Allocate hugepages
    echo 200 > /proc/sys/vm/nr_hugepages
    umount "${mount_point}" > /dev/null 2>&1 || true
    mkdir -p "${mount_point}"
    mount -t hugetlbfs hugetlbfs "${mount_point}"
}

libhugetlbfs_cleanup() {
    umount "${mount_point}" > /dev/null 2>&1 || true
    if [ -n "${CWD}" ]; then
       # shellcheck disable=SC2164
       cd "${CWD}"
       rm -rf libhugetlbfs-"${VERSION}" > /dev/null 2>&1 || true
       rm -rf libhugetlbfs-"${VERSION}".tar.gz > /dev/null 2>&1 || true
    fi
}

libhugetlbfs_build_test() {
    # shellcheck disable=SC2140
    # Upstream tree
#    wget https://github.com/libhugetlbfs/libhugetlbfs/releases/download/"${VERSION}"/libhugetlbfs-"${VERSION}".tar.gz
    #TODO
    # Private tree with CentOS build fix
    # When patch is upstream remove private tree and enable upstream tree
    #wget http://github.com/nareshkamboju/libhugetlbfs/releases/download/"${VERSION}"/libhugetlbfs-"${VERSION}".tar.gz
   # wget http://htsat.vicp.cc:804/libhugetlbfs-2.20.tar.gz
   git clone https://github.com/libhugetlbfs/libhugetlbfs.git
   git reset --hard e44180072b796c0e28e53c4d01ef6279caaa2a99
    CWD=$(pwd)
    #tar -xvf libhugetlbfs-"${VERSION}".tar.gz
    # shellcheck disable=SC2164
    #cd libhugetlbfs-"${VERSION}"
    cd libhugetlbfs
    make BUILDTYPE=NATIVEONLY
}

libhugetlbfs_run_test() {
    # shellcheck disable=SC2164
    cd tests
    # Run tests
    # Redirect stdout (not stderr)
    ./run_tests.py -b "${WORD_SIZE}" | tee -a "${TMP_LOG}"
    parse_output
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="binutils gcc make python sed tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        print_info $? install-pkgs
        ;;
      fedora|centos)
        pkgs="binutils gcc glibc-static make python sed tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        print_info $? install-pkgs
        ;;
      opensuse)
	pkgs="binutils gcc glibc-devel-static make python sed tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        print_info $? install-pkgs
        ;;
    esac
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"
# shellcheck disable=SC2164
cd "${OUTPUT}"

info_msg "About to run libhugetlbfs test..."
info_msg "Output directory: ${OUTPUT}"

if [ -f /proc/config.gz ]
then
CONFIG_HUGETLBFS=$(zcat /proc/config.gz | grep "CONFIG_HUGETLBFS=")
CONFIG_HUGETLB_PAGE=$(zcat /proc/config.gz | grep "CONFIG_HUGETLB_PAGE=")
elif [ -f /boot/config-"$(uname -r)" ]
then
KERNEL_CONFIG_FILE="/boot/config-$(uname -r)"
CONFIG_HUGETLBFS=$(grep "CONFIG_HUGETLBFS=" "${KERNEL_CONFIG_FILE}")
CONFIG_HUGETLB_PAGE=$(grep "CONFIG_HUGETLB_PAGE=" "${KERNEL_CONFIG_FILE}")
else
exit_on_skip "libhugetlb-pre-requirements" "Kernel config file not available"
fi

HUGETLBFS=$(grep hugetlbfs /proc/filesystems | awk '{print $2}')

[ "${CONFIG_HUGETLBFS}" = "CONFIG_HUGETLBFS=y" ] && [ "${CONFIG_HUGETLB_PAGE}" = "CONFIG_HUGETLB_PAGE=y" ] && [ "${HUGETLBFS}" = "hugetlbfs" ]
exit_on_skip "libhugetlb-pre-requirements" "Kernel config CONFIG_HUGETLBFS=y and CONFIG_HUGETLB_PAGE=y not enabled"

# Install packages
install

# Setup libhugetlbfs mount point
libhugetlbfs_setup

PRE_BUILD_PATH="$(find /usr/lib*/libhugetlbfs -type f -name run_tests.py)"

if [ -n "${PRE_BUILD_PATH}" ]
then
    echo "pre built libhugetlbfs found on rootfs"
    # shellcheck disable=SC2164
    cd /usr/lib*/libhugetlbfs
else
    # Build libhugetlbfs tests
    libhugetlbfs_build_test
fi
# Run libhugetlbfs tests
libhugetlbfs_run_test

# Unmount libhugetlbfs mount point
libhugetlbfs_cleanup
