#!/bin/bash

VERSION=$1
RELEASE=$2
ELVER=${3:-9}  # 默认9，可传10、fedora41等
ARCH=${4:-$(uname -m)}  # 默认当前架构

umask 0022

TEMPDIR=$(mktemp -d)
INSTDIR=$(mktemp -d)

trap "rm -rf $TEMPDIR $INSTDIR" EXIT

mkdir -p $TEMPDIR/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
echo "%_topdir $TEMPDIR" > $TEMPDIR/macros

# 判断 Fedora 用 /usr/lib，其它用 /usr/lib64
if [[ $ELVER == fedora* ]]; then
  LIBDIR=usr/lib
else
  LIBDIR=usr/lib64
fi

mkdir -p -m 0755 $INSTDIR/etc/foundationdb
mkdir -p -m 0755 $INSTDIR/etc/rc.d/init.d
mkdir -p -m 0755 $INSTDIR/lib/systemd/system
mkdir -p -m 0755 $INSTDIR/usr/bin
mkdir -p -m 0755 $INSTDIR/usr/sbin
mkdir -p -m 0755 $INSTDIR/$LIBDIR
mkdir -p -m 0755 $INSTDIR/usr/include/foundationdb
mkdir -p -m 0755 $INSTDIR/usr/share/doc/foundationdb-clients
mkdir -p -m 0755 $INSTDIR/usr/share/doc/foundationdb-server
mkdir -p -m 0755 $INSTDIR/var/log/foundationdb
mkdir -p -m 0755 $INSTDIR/usr/lib/foundationdb/backup_agent
mkdir -p -m 0755 $INSTDIR/var/lib/foundationdb/data

set -e
install -m 0644 packaging/foundationdb.conf $INSTDIR/etc/foundationdb
install -m 0755 packaging/rpm/foundationdb-init $INSTDIR/etc/rc.d/init.d/foundationdb
install -m 0644 packaging/rpm/foundationdb.service $INSTDIR/lib/systemd/system/foundationdb.service
install -m 0755 bin/fdbcli $INSTDIR/usr/bin
install -m 0755 bin/fdbserver $INSTDIR/usr/sbin
install -m 0755 bin/fdbmonitor $INSTDIR/usr/lib/foundationdb
install -m 0755 lib/libfdb_c.so $INSTDIR/$LIBDIR
install -m 0755 lib/libfdb_c_shim.so $INSTDIR/$LIBDIR
install -m 0644 bindings/c/foundationdb/fdb_c.h bindings/c/foundationdb/fdb_c_options.g.h bindings/c/foundationdb/fdb_c_types.h bindings/c/foundationdb/fdb_c_internal.h bindings/c/foundationdb/fdb_c_shim.h fdbclient/vexillographer/fdb.options $INSTDIR/usr/include/foundationdb
dos2unix -q -n README.md $INSTDIR/usr/share/doc/foundationdb-clients/README
dos2unix -q -n README.md $INSTDIR/usr/share/doc/foundationdb-server/README
chmod 0644 $INSTDIR/usr/share/doc/foundationdb-clients/README
chmod 0644 $INSTDIR/usr/share/doc/foundationdb-server/README
install -m 0755 bin/fdbbackup $INSTDIR/usr/lib/foundationdb/backup_agent/backup_agent
install -m 0755 packaging/make_public.py $INSTDIR/usr/lib/foundationdb

ln -s ../lib/foundationdb/backup_agent/backup_agent $INSTDIR/usr/bin/fdbbackup
ln -s ../lib/foundationdb/backup_agent/backup_agent $INSTDIR/usr/bin/fdbrestore
ln -s ../lib/foundationdb/backup_agent/backup_agent $INSTDIR/usr/bin/fdbdr
ln -s ../lib/foundationdb/backup_agent/backup_agent $INSTDIR/usr/bin/dr_agent

(cd $INSTDIR ; tar -czf $TEMPDIR/SOURCES/install-files.tar.gz *)

if [[ $ELVER == fedora* ]]; then
  FEDORA_VER=${ELVER#fedora}
  M4_EXTRA="-DFEDORA=$FEDORA_VER"
else
  M4_EXTRA="-DRHEL=$ELVER"
fi

m4 -DFDBVERSION=$VERSION -DFDBRELEASE=$RELEASE.el${ELVER} $M4_EXTRA packaging/rpm/foundationdb.spec.in > $TEMPDIR/SPECS/foundationdb.el${ELVER}.${ARCH}.spec

fakeroot rpmbuild --target ${ARCH} --quiet --define "%_topdir $TEMPDIR" -bb $TEMPDIR/SPECS/foundationdb.el${ELVER}.${ARCH}.spec

cp $TEMPDIR/RPMS/${ARCH}/*.rpm packages
