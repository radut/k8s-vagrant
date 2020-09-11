```
kubectl run ubuntu-radu --rm -ti --limits="cpu=200m,memory=512Mi" --image=radut/ubuntu --restart=Never /bin/bash

kubectl run ubuntu-radu --generator=run-pod/v1 --rm -ti --limits="cpu=200m,memory=512Mi" --image=radut/ubuntu  /bin/bash




kubectl run ubuntu-radu --rm -ti --limits="cpu=200m,memory=512Mi" --image=radut/varnish --restart=Never /bin/bash


kubectl get pods --show-labels

kubectl get pods -o wide --sort-by="{.spec.nodeName}"


kubectl run ubuntu-radu --rm -ti --image=radut/ubuntu --restart=Never /bin/bash

```
