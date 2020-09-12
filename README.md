# Readme
* https://linuxconfig.org/how-to-install-kubernetes-on-ubuntu-18-04-bionic-beaver-linux

* https://pkg.go.dev/k8s.io/kubernetes@v1.18.8/cmd/kubeadm/app/apis/kubeadm/v1beta2?tab=doc
```
kubeadm init ...

kubeadm reset 

kubeadm config print init-defaults
kubeadm config print join-defaults



kubectl taint node k8s-master node-role.kubernetes.io/master=:NoSchedule
kubectl taint node k8s-master node-role.kubernetes.io/master-

kubeadm token create --print-join-command


export KUBECONFIG=`pwd`/kube.config

```

#### https://github.com/kubernetes/kubeadm/issues/203#issuecomment-478206793
Just ran into this in "Kubeadm 1.13". Fixed it using the following:

Add "--node-ip" to '/var/lib/kubelet/kubeadm-flags.env':
[root@Node-18121 ~]# cat /var/lib/kubelet/kubeadm-flags.env
```
KUBELET_KUBEADM_ARGS=--cgroup-driver=systemd --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.1 --node-ip=10.10.10.1
```
Restart Kubelet:
```
export NODE_IP="$(ip addr list |grep 'inet '|grep 172.16.|cut -d' ' -f6|cut -d/ -f1)" 
cat /var/lib/kubelet/kubeadm-flags.env | sed 's|--node-ip=[a-zA-Z\.0-9]*||g' | sed "s|\"$| --node-ip=$NODE_IP\"|g" | sponge /var/lib/kubelet/kubeadm-flags.env
systemctl daemon-reload && systemctl restart kubelet
```


### Deployment example
```
kubectl create deployment --image radut/my-nginx my-nginx
kubectl expose deployment my-nginx --port=80 --type=LoadBalancer
kubectl scale deployment --replicas 2 my-nginx
dig @10.102.0.10 my-nginx.default.svc.cluster.local
```



### helm
```
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kube-eagle https://raw.githubusercontent.com/google-cloud-tools/kube-eagle-helm-chart/master
helm repo update

helm install kubeapps bitnami/kubeapps --set useHelm3=true




cat > cluster-admin.yml <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-admin
  namespace: default
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-rb
subjects:
  - kind: ServiceAccount
    name: cluster-admin
    namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---


#apiVersion: rbac.authorization.k8s.io/v1
#kind: ClusterRole
#metadata:
#  annotations:
#    rbac.authorization.kubernetes.io/autoupdate: "true"
#  labels:
#    kubernetes.io/bootstrapping: rbac-defaults
#  name: cluster-admin
#rules:
#- apiGroups:
#  - '*'
#  resources:
#  - '*'
#  verbs:
#  - '*'
#- nonResourceURLs:
#  - '*'
#  verbs:
#  - '*'
#---
EOF

kubectl apply -f cluster-admin.yml


kubectl get -n default secret $(kubectl get -n default serviceaccount cluster-admin -o jsonpath='{.secrets[].name}') -o go-template='{{.data.token | base64decode}}' && echo

kubectl get svc 

```




```
dig +time=2 +tries=1 +noall +answer @192.168.16.90  google.ro

kdig -d @1.1.1.1 +tls-ca +tls-host=cloudflare-dns.com  example.com

brew tap blendle/blendle; brew install kns

kubectl run ubuntu-radu --rm -ti --limits="cpu=200m,memory=512Mi" --image=radut/ubuntu --restart=Never /bin/bash

kubectl run ubuntu-radu --generator=run-pod/v1 --rm -ti --limits="cpu=200m,memory=512Mi" --image=radut/ubuntu  /bin/bash


kubectl get pods --show-labels

kubectl get pods -o wide --sort-by="{.spec.nodeName}"


kubectl run ubuntu-radu --rm -ti --image=radut/ubuntu --restart=Never /bin/bash


# Display only the most recent 20 lines of output in pod nginx
kubectl logs --tail=20 nginx

# Show all logs from pod nginx written in the last hour
kubectl logs --since=1h nginx

```
