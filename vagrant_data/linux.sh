#!/usr/bin/env bash
for arg in "$@"; do
    case $arg in
        --with-helm)
        HELM=true
        ;;
        --with-docker)
        DOCKER=true
        ;;
        --with-kubernetes)
        KUBERNETES=true
        ;;
    	--with-kubeadm-init)
		KUBEADM_INIT=true
		;;
        --disable-swap)
        DISABLE_SWAP=true
        ;;
        --with-mount)
        MOUNT=true
        ;;
        --vm)
        VM=true
        ;;
        *)
              # unknown option
        ;;
    esac
done

set -ex
BASEDIR=$(dirname $0)

if [ "$DOCKER" = true ]; then
   echo "Installing Docker"
   apt-get install -y -q ca-certificates curl software-properties-common
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
   add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
   apt-get update
   apt-get install -y -q docker.io
   if [ -z "$VM" ]; then
      groupadd docker
      usermod -aG docker $SUDO_USER
   fi
   mkdir -p /etc/systemd/system/docker.service.d
   cat <<EOF > /etc/systemd/system/docker.service.d/docker.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock
EOF
   echo "export DOCKER_HOST=tcp://0.0.0.0:2375" >> $HOME/.bashrc
   source $HOME/.bashrc
   systemctl enable docker
   systemctl daemon-reload
   systemctl restart docker
fi

if [ "$DISABLE_SWAP" = true ]; then
    echo "Disabling swap permanently"
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
fi

if [ "$HELM" = true ]; then
#helm2
#    curl -s https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash -s -- "--version" "${HELM_VERSION:-latest}"
#helm3
    #curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -s -- "--version" "${HELM_VERSION:-latest}"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -
fi

if [ "$KUBERNETES" = true ]; then
   swapoff -a
   echo "Installing kubeadm, kubectl, kubelet"
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
   cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
   deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

   apt-get update
   apt-get install -y -q kubectl=1.18.8-00 kubelet=1.18.8-00 kubeadm=1.18.8-00
   apt-get install -y -q ceph-common jq moreutils
   apt-mark hold kubeadm kubelet kubectl

   echo "Enabling kubelet service"
   systemctl enable kubelet
   cat <<EOF > /etc/resolv-kube.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

NODE_IP="$(ip addr list |grep 'inet '|grep 172.16.|cut -d' ' -f6|cut -d/ -f1)"

#mkdir -p /var/lib/kubelet/
#cat > /var/lib/kubelet/kubeadm-flags.env <<EOF
#KUBELET_KUBEADM_ARGS="--cgroup-driver=cgroupfs --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.2 --resolv-conf=/run/systemd/resolve/resolv.conf --node-ip=${NODE_IP}"
#EOF

#NODE_IP="$(ip addr list |grep 'inet '|grep 172.16.|cut -d' ' -f6|cut -d/ -f1)" cat /var/lib/kubelet/kubeadm-flags.env | sed 's|--node-ip=[a-zA-Z\.0-9]*||g' | sed "s|\"$| --node-ip=$NODE_IP\"|g" | sponge /var/lib/kubelet/kubeadm-flags.env

   systemctl daemon-reload
   systemctl restart docker
   systemctl restart kubelet

    if [ "$KUBEADM_INIT" = true ]; then
       echo "Bootstraping cluster"
       if [ -z "$VM" ]; then
          sed -i '/.advertiseAddress./d' $BASEDIR/kubeadm.yaml
       fi
       kubeadm init --config=$BASEDIR/kubeadm.yaml

       echo "Copying kube confing to user home"
       mkdir -p $HOME/.kube
       cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
       chown -R $SUDO_USER: $HOME/.kube

       if [ "$VM" = true ]; then
          chown -R vagrant: /etc/kubernetes/admin.conf
       fi

       echo "alias k=kubectl" >> $HOME/.bashrc
       echo 'alias k=kubectl' >> $HOME/.bashrc
       echo 'complete -F __start_kubectl k' >> $HOME/.bashrc
       kubectl completion bash >/etc/bash_completion.d/kubectl

       echo "Installing calico network"
    #    kubectl taint nodes --all node-role.kubernetes.io/master-
    #    kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
    #    kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

        kubectl taint nodes --all node-role.kubernetes.io/master-
        echo "k8s-master default taint: kubectl taint node k8s-master node-role.kubernetes.io/master=:NoSchedule"
        echo "k8s-master remove taint : kubectl taint node k8s-master node-role.kubernetes.io/master-"

        ## less than 50 nodes
        kubectl create -f https://docs.projectcalico.org/manifests/calico.yaml
        ## more than 50 nodes
        # kubectl create -f https://docs.projectcalico.org/manifests/calico-typha.yaml


        cp /etc/kubernetes/admin.conf /vagrant/kube.config

        echo "kubectl create deployment --image radut/my-nginx my-nginx"
        echo "kubectl expose deployment my-nginx --port=80 --type=LoadBalancer"
        echo "kubectl scale deployment --replicas 2 my-nginx"
        echo "dig @10.102.0.10 my-nginx.default.svc.cluster.local"


        echo "# For local access"
        echo "export KUBECONFIG=\`pwd\`/kube.config"
        echo "get token for join: kubeadm token create --print-join-command"
        echo "on node : bash /vagrant/vagrant_data/join.sh 172.16.16.10 --token=xxxxxxx"
        echo "kubectl get pods"

    fi
fi

