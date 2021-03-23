#!/usr/bin/env bash

set -e

LOCALDIR="$(dirname $0)"

apt-get -qqy update
# Cleaning up
apt-get -qqy purge $(dpkg -l | egrep 'juju|chef|puppet|ruby|rpcbind' | awk '{print $2}' | xargs) && apt-get -qqy --purge autoremove
apt-get -qqy install python-magic python3-pip jq pwgen
pip3 install ceph-deploy s3cmd yq yasha

cd /vagrant
bash generate-secrets.sh || true

CEPH_NODE="$(hostname)"
CEPH_NODE_IP="$(ip addr list |grep 'inet '|grep 192|cut -d' ' -f6|cut -d/ -f1)"
CEPH_PUBLIC_NETWORK="192.168.10.0/24"

#CEPH_RELEASE="octopus"
CEPH_RELEASE="nautilus"
DATA_DISK="/dev/osd/osd_data"

DATA_DEV_SIZE="${DATA_DEV_SIZE:="40G"}"

RGW_BUCKET="`cat secrets.yml | yq -r .ceph_rgw_bucket`"
RGW_USER="`cat secrets.yml | yq -r .ceph_rgw_user`"
RGW_ACCESSKEY="`cat secrets.yml | yq -r .ceph_rgw_access_key`"
RGW_SECRET="`cat secrets.yml | yq -r .ceph_rgw_secret_key`"
RGW_PORT="8080"

CEPH_DASHBOARD_ADMIN_PASSWORD="`cat secrets.yml | yq -r .ceph_dashboard_admin_password`"


[[ -f ${HOME}/.ssh/id_rsa ]] || ssh-keygen -t rsa -N "" -f ${HOME}/.ssh/id_rsa
cat ${HOME}/.ssh/id_rsa.pub >> ${HOME}/.ssh/authorized_keys
[[ -n $(grep $(hostname) /etc/hosts) ]] \
&& sed -i "s/.*$(hostname).*/${CEPH_NODE_IP} ${CEPH_NODE} ${RGW_BUCKET}.${CEPH_NODE}/g" /etc/hosts \
|| echo "${CEPH_NODE_IP} ${CEPH_NODE} ${RGW_BUCKET}.${CEPH_NODE}" >> /etc/hosts

mkdir -p /opt/ceph-deploy && cd /opt/ceph-deploy

ceph-deploy -q install --mon --osd --rgw --mds --release ${CEPH_RELEASE} ${CEPH_NODE}

apt-get install -y ceph-mgr-dashboard

ceph-deploy -q new --public-network ${CEPH_PUBLIC_NETWORK} ${CEPH_NODE}

cat >./ceph.conf<<EOF
[global]
fsid = `uuidgen`
public_network = ${CEPH_PUBLIC_NETWORK}
mon_initial_members = ceph-aio
mon_host = ${CEPH_NODE_IP}
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx

osd crush chooseleaf type = 0
osd pool default size = 1

osd pool default pg num = 16
osd pool default pgp num = 16

[client.rgw.ceph-aio]
host = ceph-aio
rgw dns name = ceph-aio
rgw_frontends = "civetweb port=${RGW_PORT}"
rgw print continue = false
EOF


ceph-deploy -q mon create-initial
ceph-deploy -q mgr create ${CEPH_NODE}

echo "Creating block device for ceph OSD (${DATA_DEV_SIZE})..."
dd if=/dev/zero of=/ceph.osd bs=1 count=0 seek=${DATA_DEV_SIZE}
losetup /dev/loop0 /ceph.osd

cat > /etc/rc.local<<EOF
#!/bin/bash

losetup /dev/loop0 /ceph.osd || true

exit 0
EOF

cat >/etc/systemd/system/rc-local.service<<EOF
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

chmod +x /etc/rc.local

systemctl enable rc.local

vgcreate osd /dev/loop0
lvcreate -l 100%FREE -n osd_data osd

ceph-deploy -q osd create --data ${DATA_DISK} ${CEPH_NODE}

ceph -c /opt/ceph-deploy/ceph.conf -k /opt/ceph-deploy/ceph.client.admin.keyring -s

cat > /etc/ceph/ceph.client.admin.keyring <<EOF
[client.admin]
  key = `cat /vagrant/secrets.yml | yq -r '.ceph_secret_admin'`
  caps mds = "allow *"
  caps mgr = "allow *"
  caps mon = "allow *"
  caps osd = "allow *"
EOF
cat > /etc/ceph/ceph.client.kube.keyring <<EOF
[client.kube]
  key = `cat /vagrant/secrets.yml | yq -r '.ceph_secret_user'`
  caps mon = "allow r"
  caps osd = "allow class-read object_prefix rbd_children, allow rwx pool=rbd"
EOF

ceph -c /opt/ceph-deploy/ceph.conf -k /opt/ceph-deploy/ceph.client.admin.keyring auth import -i /etc/ceph/ceph.client.admin.keyring
cp -av /etc/ceph/ceph.client.admin.keyring /opt/ceph-deploy/ceph.client.admin.keyring
ceph -c /opt/ceph-deploy/ceph.conf -k /opt/ceph-deploy/ceph.client.admin.keyring auth import -i /etc/ceph/ceph.client.kube.keyring

cd /etc/ceph
ceph-deploy -q gatherkeys ${CEPH_NODE}

ceph config set global mon_warn_on_pool_no_redundancy false

ceph mgr module enable dashboard --force
ceph config set mgr "mgr/dashboard/ssl" "false"
ceph config set mgr "mgr/dashboard/server_addr" "192.168.10.10"
ceph config set mgr "mgr/dashboard/server_port" "8443"
#ceph dashboard ac-user-create ceph ceph read-only
ceph dashboard ac-user-create admin ${CEPH_DASHBOARD_ADMIN_PASSWORD} administrator
ceph mgr module disable dashboard || true
ceph mgr module enable dashboard --force

ceph osd pool create rbd 16
ceph osd pool set rbd size 1
ceph osd pool set rbd min_size 1
ceph osd pool application enable rbd rbd || true

ceph-deploy -q mds create ${CEPH_NODE}
ceph osd pool create cephfs_data 16
ceph osd pool create cephfs_meta 16
ceph fs new cephfs cephfs_meta cephfs_data

ceph-deploy -q rgw create ${CEPH_NODE}

radosgw-admin user create --uid=${RGW_USER} --display-name=${RGW_USER} --access-key=${RGW_ACCESSKEY} --secret=${RGW_SECRET}
radosgw-admin user create --uid='rgw-admin' --display-name='RGW Admin' --system
radosgw-admin caps add --uid=rgw-admin --caps='users=*;buckets=*;metadata=*;usage=*;zone=*'

ceph dashboard set-rgw-api-ssl-verify False
ceph dashboard set-rgw-api-scheme http
ceph dashboard set-rgw-api-admin-resource admin
ceph dashboard set-rgw-api-user-id rgw-admin
ceph dashboard set-rgw-api-port ${RGW_PORT}
ceph dashboard set-rgw-api-host ${CEPH_NODE_IP}

ceph dashboard set-rgw-api-access-key `radosgw-admin user info --uid=rgw-admin | jq -r .keys[].access_key`
ceph dashboard set-rgw-api-secret-key `radosgw-admin user info --uid=rgw-admin | jq -r .keys[].secret_key`

ceph dashboard feature disable iscsi mirroring

ceph mgr module disable dashboard
ceph mgr module enable dashboard


s3cmd --no-ssl --access_key=${RGW_ACCESSKEY} --secret_key=${RGW_SECRET} --host=${CEPH_NODE_IP}:${RGW_PORT} --host-bucket=${CEPH_NODE_IP}:${RGW_PORT} mb s3://${RGW_BUCKET}
s3cmd --no-ssl --access_key=${RGW_ACCESSKEY} --secret_key=${RGW_SECRET} --host=${CEPH_NODE_IP}:${RGW_PORT} --host-bucket=${CEPH_NODE_IP}:${RGW_PORT} --dump-config | tee ${HOME}/.s3cfg

#s3cmd --configure -c ${HOME}/.s3cfg

s3cmd mb s3://${RGW_BUCKET} > /dev/null
echo "test html" > /tmp/test.html
s3cmd --acl-public put /tmp/test.html s3://${RGW_BUCKET} > /dev/null

echo "================================================================================================="
echo "RadosGW installed successfully and listens on http://${CEPH_NODE_IP}:${RGW_PORT}"
echo "Public.yml test : http://${CEPH_NODE_IP}:${RGW_PORT}/${RGW_BUCKET}/test.html via web browser"
echo "================================================================================================="

ceph osd lspools

ceph auth get-or-create client.kube mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=rbd' -o /etc/ceph/ceph.client.kube.keyring
echo "client.kube"
ceph auth get-key client.kube | base64
echo "client.admin"
ceph auth get-key client.admin | base64
echo ""
echo "Ceph Dashboard http://192.168.10.10:8443  credentials: admin/${CEPH_DASHBOARD_ADMIN_PASSWORD}"
echo ""
ceph osd metadata | jq '.[] | {id,hostname,osd_data,osd_objectstore,front_addr,back_addr}'
echo ""
ceph -s
echo ""
#cat /vagrant/ceph-aio/rbd_provisioner/readme.md|grep is-def -B1
echo kubectl patch storageclass/hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
echo ""

#kubectl patch storageclass/hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
