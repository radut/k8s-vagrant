### docs

* https://tachingchen.com/blog/kubernetes-rolling-update-with-deployment/

### how to auth to private registry
```bash

kubectl create secret docker-registry docker-io --docker-server=https://index.docker.io/v1/ --docker-username=radut --docker-password='Cheivoh5' --docker-email=radu.m.toader@gmail.com

kubectl create secret docker-registry nexus-registry --docker-server=https://registry.radut.xyz --docker-username=radu --docker-password='jar!press' --docker-email=radu@radutoader.info

kubectl create secret docker-registry gitlab-registry --docker-server=https://docker-registry.radut.xyz --docker-username=radu --docker-password='git!press' --docker-email=radu@radutoader.info





#    spec:
#      imagePullSecrets:
#        - name: docker-io

```



## udpate image version
```bash
kubectl apply -f create-deployment-and-svc.yml

kubectl get rs -o wide

kubectl get rs -l app=js-app


#or just update image

kubectl set image deployment/js-app js-app=radut/js-app:v1
kubectl set image deployment/js-app js-app=radut/js-app:v2

kubectl scale deploy/js-app --replicas=6

## rollout status, which waits for rollout to happen !
kubectl rollout status deployment js-app

## rollout restart
kubectl rollout restart deployment js-app

watch -n0.1 kubectl get rs -l "app=js-app"


# check image version - and desired /current state

```
### kubectl get only names
```bash
kubectl get deploy -o name
```




### GitLab CI kubectl
```yml
image: google/cloud-sdk:latest
script:
    - docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} nexus-registry.com
    - kubectl config set-cluster kb-prod --server=https://kube-cluster.com --insecure-skip-tls-verify=true
    - kubectl config set-credentials kb-ci --token=${KUBE_SA_KB_PROD}
    - kubectl config set-context kb-prod --user=kb-ci --cluster=omfe-prod --namespace=omfe-prod
    - kubectl config use-context kb-prod


```
### Patch a deployment - change only a few things like replicas / liveness probe..etcc
```bash
kubectl patch deployment patch-demo --patch "$(cat patch-file-containers.yaml)"
```



