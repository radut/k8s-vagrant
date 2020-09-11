
API_ENDPOINT="$1"
TOKEN=""


POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --api-endpoint)
    API_ENDPOINT="$2"
    shift # past argument
    shift # past value
    ;;
    --token)
    TOKEN="$2"
    shift # past argument
    shift # past value
    ;;
#    --default)
#    DEFAULT=YES
#    shift # past argument
#    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

echo api=$API_ENDPOINT
echo token=$TOKEN

export NODE_IP="$(ip addr list |grep 'inet '|grep 172.16.|cut -d' ' -f6|cut -d/ -f1)"

cat > join.yml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: ${API_ENDPOINT}
    token: ${TOKEN}
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: ${TOKEN}
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    node-ip: "${NODE_IP}"
  criSocket: /var/run/dockershim.sock
  name: `hostname`
  taints: null
EOF


kubeadm join --skip-phases=preflight --config=join.yml
