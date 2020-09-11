#!/bin/bash

FILE=secrets.yml
if test -f "$FILE"; then
    echo "$FILE already exists. To regenerate secrets please delete the file"
    FILE_EXISTS="yes"
fi

if [ "$FILE_EXISTS" != "yes" ];then

CEPH_SECRET_ADMIN=`python2 -c "import os ; import struct ; import time; import base64 ; key = os.urandom(16) ; header = struct.pack('<hiih',1,int(time.time()),0,len(key)) ; print(base64.b64encode(header + key))"`
CEPH_SECRET_USER=`python2 -c "import os ; import struct ; import time; import base64 ; key = os.urandom(16) ; header = struct.pack('<hiih',1,int(time.time()),0,len(key)) ; print(base64.b64encode(header + key))"`

cat > $FILE <<EOF
ceph_secret_admin: ${CEPH_SECRET_ADMIN}
ceph_secret_user: ${CEPH_SECRET_USER}


ceph_secret_admin_base64: `echo ${CEPH_SECRET_ADMIN} | base64`
ceph_secret_user_base64: `echo ${CEPH_SECRET_USER} | base64`

ceph_rgw_access_key: "`pwgen 20`"
ceph_rgw_secret_key: "`pwgen 40`"

ceph_dashboard_admin_password: "`pwgen 5`"

ceph_rgw_bucket: "bucket"
ceph_rgw_user: "user"

EOF
fi

#rm -rf rbd_provisioner/*.yml
#rm -rf cephfs_provisioner/*.yml

find rbd_provisioner -type f -iname *.j2 |xargs -I{} bash -c "yasha -v secrets.yml {}"
find cephfs_provisioner -type f -iname *.j2 |xargs -I{} bash -c "yasha -v secrets.yml {}"

