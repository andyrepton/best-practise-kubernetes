# Workshop 1: Installing Helm and Connecting to our clusters

## Install kubectl if you don't have it
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.9.6/bin/darwin/amd64/kubectl
chnod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## Install Helm if you don't have it
```
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-darwin-amd64.tar.gz
tar zvxf helm-v2.9.1-darwin-amd64.tar.gz
chmod +x darwin-amd64/helm
sudo mv darwin-amd64/helm /usr/local/bin/
```

## Connect to your cluster
Using the script in this repository, run the workshop.sh script using your assigned number. For example, if you are user 18 you would run:
```
./workshop.sh connect user18
```

Then, either use the `--kubeconfig` flag from now on to kubectl for the rest of the workshop, or backup your existing kubeconfig and move this one in it's place:

```
mv ~/.kube/config my_kube_config_backup
mv user18.kubeconfig ~/.kube/config
```

## Initializing Helm and installing Tiller
```
helm init
```

## Creating the correct accounts and permissions in our cluster
```
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```

## Confirm Tiller is running:
```
kubectl -n kube-system get pods | grep tiller
```

