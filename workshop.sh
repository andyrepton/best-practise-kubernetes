#!/bin/bash

# Automatically do each of the steps of the workshop

download_and_install_helm() {
  echo "Downloading and installing helm. This will prompt for your sudo password to move the helm binary into /usr/local/bin"
  curl -LO https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-darwin-amd64.tar.gz
  tar zvxf helm-v2.9.1-darwin-amd64.tar.gz
  chmod +x darwin-amd64/helm
  sudo mv darwin-amd64/helm /usr/local/bin/
  /usr/local/bin/helm init
}

configure_helm_serviceaccount() {
  kubectl create serviceaccount --namespace kube-system tiller
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
}

install_first_wordpress() {
  helm install --name first-wordpress --set wordpressBlogName="DevOpsDays blog" stable/wordpress
  kubectl get svc --namespace default -o wide
}

purge_first_wordpress() {
  helm del --purge first-wordpress
}

install_stateful_mariadb() {
  helm install --name my-wordpress-db --set root.password=devopsdays,db.user=bn_wordpress,db.password=devopsdays,db.name=devopsdays,slave.replicas=2 stable/mariadb
  kubectl get svc -o wide
}

install_second_wordpress() {
  helm install --name my-wordpress --set wordpressBlogName="DevOpsDays blog",mariadb.enabled=false,externalDatabase.host=my-wordpress-db-mariadb,externalDatabase.password=devopsdays,externalDatabase.database=devopsdays,externalDatabase.port=3306,persistence.accessMode=ReadWriteMany stable/wordpress
  sleep 10
  kubectl get svc
}

cleanup_second_wordpress() {
  helm del --purge my-wordpress
}

install_nfs_provisioner() {
  helm install --name my-nfs stable/nfs-server-provisioner
}

install_second_wordpress_again() {
  helm install --name my-wordpress --set wordpressBlogName="DevOpsDays blog",mariadb.enabled=false,externalDatabase.host=my-wordpress-db-mariadb,externalDatabase.password=devopsdays,externalDatabase.database=devopsdays,externalDatabase.port=3306,persistence.storageClass=nfs stable/wordpress
}

scale_up_second_wordpress() {
  kubectl scale deployment my-wordpress-wordpress --replicas=3
}

cleanup_workshop2() {
  echo Cleaning up Workshop2, this will take a couple of minutes
  kubectl scale deployment my-wordpress-wordpress --replicas=1
  helm del --purge my-wordpress
  helm del --purge my-nfs
  helm del --purge my-wordpress-db
  kubectl delete pvc --all
}

deploy_first_image() {
  kubectl run devopsdays --image sethkarlo/nginx:dod-first
}

upgrade_first_image() {
  kubectl patch deployment devopsdays -p '{"spec":{"template":{"spec":{"containers":[{"name":"devopsdays","image":"sethkarlo/nginx:dod-second"}]}}}}'
}

patch_ready() {
  kubectl apply -f 3-Probes/readiness_patch.yml
}
patch_liveness() {
  kubectl apply -f 3-Probes/liveness_patch.yml
}

cleanup_workshop3() {
  kubectl delete deployment devopsdays
}

deploy_quota() {
  kubectl create namespace devopsdays-demo
  kubectl create -f 4-Quotas_and_Limits/quota.yml
}

create_100_replicas() {
  kubectl -n devopsdays-demo run nginx --image=nginx:stable --replicas=100
}

connect_to_my_cluster() {
  echo Hello $1
  cluster_name=$1
  curl -s -LO https://s3-eu-west-1.amazonaws.com/devopsdays-ams-public/${cluster_name}.kubeconfig 
  cat <<EOF
  ####

  Your cluster's kubeconfig is now in the current directory as ${cluster_name}.kubeconfig.
  Please copy this to ~/.kube/config
  *** This script will NOT move the file for you ***
  PLEASE BACK UP YOUR EXISTING CONFIG FIRST!!

  ####
EOF
    read -p "Please confirm you will back up your config by typing yes (and that Andy is not responsible if you don't): "
    echo
    if [ ${REPLY} == "yes" ]; then
      exit 0
    else
      echo "Well, you can't say you weren't warned"
      exit 1
    fi
}

usage() {
  cat <<EOF
Welcome to the devopsdays workshop! Please re-run this script with your user number and the argument 'connect'. For example, if you are user 22, run:

./workshop.sh connect user22

Any questions at any time please just ask Andy. I hope you enjoy the workshop!
EOF

}

if [ -z $1 ]; then usage ; exit 0; fi

for cmd in "$@"; do
shift
case ${cmd} in
  workshop1-1)
  download_and_install_helm
  configure_helm_serviceaccount 
  ;;
  workshop2-1)
  install_first_wordpress
  ;;
  workshop2-2)
  purge_first_wordpress
  ;;
  workshop2-3)
  install_stateful_mariadb
  ;;
  workshop2-4)
  install_second_wordpress
  ;;
  workshop2-5)
  cleanup_second_wordpress
  install_nfs_provisioner
  install_second_wordpress_again
  ;;
  workshop2-6)
  scale_up_second_wordpress
  ;;
  workshop2-cleanup)
  cleanup_workshop2
  ;;
  workshop3-1)
  deploy_first_image
  ;;
  workshop3-2)
  upgrade_first_image
  ;;
  workshop3-3)
  patch_ready
  ;;
  workshop3-4)
  patch_liveness
  ;;
  workshop3-cleanup)
  cleanup_workshop3
  ;;
  connect)
  connect_to_my_cluster "$@"
  ;;
  *)
  usage
  ;;
esac
done
