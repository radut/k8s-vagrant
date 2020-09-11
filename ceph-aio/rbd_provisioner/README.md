add rbd on docker-for-desktop
```
docker run --rm -it --privileged --net=host --pid=host -v /usr/bin:/opt/bin ubuntu bash

cat >> /opt/bin/rbd <<EOF
#!/bin/sh
exec docker run -v /dev:/dev -v /sys:/sys --net=host --privileged=true -v /etc/ceph:/etc/ceph radut/rbd $@
EOF
chmod +x /opt/bin/rbd
```



```
kubectl patch storageclass hostpath \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass dynamic \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```



Install with RBAC roles
NAMESPACE=default # change this if you want to deploy it in another namespace
sed -r -i "s/namespace: [^ ]+/namespace: $NAMESPACE/g" ./rbac/clusterrolebinding.yaml ./rbac/rolebinding.yaml
kubectl -n $NAMESPACE apply -f ./rbac
