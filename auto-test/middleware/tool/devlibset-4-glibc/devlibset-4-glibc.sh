
#!/bin/bash 
set -x
cd ../../../../utils
source ./sys_info.sh
source ./sh-test-lib

cd -

if [ `whoami` != 'root' ] ; then
    echo "You must be the superuser to run this script" >&2
    exit 1
fi

version="2.25.90"
from_repo="Estuary"
package="devlibset-4-glibc"
for P in ${package};do
    echo "$P install"
case $distro in
    "centos" )
         yum install -y $P 
         print_info $? devlibset-4-glibc
         ;;
 esac

# Check the package version && source
from=$(yum info $P | grep "From repo" | awk '{print $4}')
if [ "$from" = "$from_repo"  ];then
      print_info 0 repo_check
else
    rmflag=1
    if [ "$from" != "Estuary"  ];then
        yum remove -y $P
        yum install -y $P
        from=$(yum info $P | grep "From repo" | awk '{print $4}')
        if [ "$from" = "$from_repo"   ];then
              print_info 0 repo_check
        else
            print_info 1 repo_check
        fi
    fi
fi

vers=$(yum info $P | grep "Version" | awk '{print $3}')
if [ "$vers" = "$version"   ];then
     print_info 0 version
else
      print_info 1 version
fi
done

# Remove package
yum remove -y $P
print_info $? remove
