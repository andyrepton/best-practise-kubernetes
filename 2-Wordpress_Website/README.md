# Workshop 2: HA with K8S: Creating a Wordpress Website

## 2-1: Creating our wordpress deployment

```
helm install --name first-wordpress --set wordpressBlogName="Andy's blog" stable/wordpress
```

This helm chart will create a Wordpress deployment for us, with a replica set, plus a second deployment of a single MariaDB instance, and expose the WordPress website with an Elastic Load Balancer. We can get the DNS name using:

```
kubectl get svc --namespace default -o wide
```

Is this Highly Available?

*** Andy goes full ChaosMonkey ***

Keep checking your website, is it still up? We can take a look at the events of your cluster using:

```
kubectl get events  --sort-by='.metadata.creationTimestamp'  -o 'go-template={{range .items}}{{.involvedObject.name}}{{"\t"}}{{.involvedObject.kind}}{{"\t"}}{{.message}}{{"\t"}}{{.reason}}{{"\t"}}{{.type}}{{"\t"}}{{.firstTimestamp}}{{"\n"}}{{end}}'
```

We can see the pod was unhealthy due to the liveness probe failing. The node was rebooted and this caused the pod to be restarted too.

## 2-2: Stateful Sets

We ensure high availability in Kubernetes not by nurturing our containers, but by creating enough replicas to survive node or pod failure. However, we have a database here, which isn't as simple as just scaling up into multiple replicas. For this, we'll use a StatefulSet.

Let's clean up our first WordPress install ready for our second go:

```
$ helm del --purge first-wordpress
```

## 2-3: Installing our Stateful Database using helm

```
helm install --name my-wordpress-db --set root.password=devopsdays,db.user=bn_wordpress,db.password=devopsdays,db.name=devopsdays,slave.replicas=2 stable/mariadb
```

The pods will be installed, with the second slave waiting until the first is created before starting up:
```
$ kubectl get pods
NAME                               READY     STATUS    RESTARTS   AGE
my-wordpress-db-mariadb-master-0   1/1       Running   0          2m
my-wordpress-db-mariadb-slave-0    1/1       Running   0          2m
my-wordpress-db-mariadb-slave-1    1/1       Running   0          1m
```

And we can see we now have two endpoints, one for our master and one for our slaves:

```
$ kubectl get svc -o wide
NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
kubernetes                      ClusterIP   100.64.0.1       <none>        443/TCP    5d        <none>
my-wordpress-db-mariadb         ClusterIP   100.67.106.217   <none>        3306/TCP   2m        app=mariadb,component=master,release=my-wordpress-db
my-wordpress-db-mariadb-slave   ClusterIP   100.69.110.47    <none>        3306/TCP   2m        app=mariadb,component=slave,release=my-wordpress-db
```

## 2-4 DB is now HA, so let's deploy a version of our wordpress with a persistent disk (ReadWriteMany) so we can scale it to multiple replicas

Once again we'll use the helm chart to install WordPress, this time setting it to use the external database we just created. For our multiple replicas, we'll also add a 'ReadWriteMany' disk, which allows for multiple pods to both read and write to the same disk:

```
$ helm install --name my-wordpress --set wordpressBlogName="Andy's blog",mariadb.enabled=false,externalDatabase.host=my-wordpress-db-mariadb,externalDatabase.password=devopsdays,externalDatabase.database=devopsdays,externalDatabase.port=3306,persistence.accessMode=ReadWriteMany stable/wordpress
```
Now, grab the new service DNS name and let's take a look at our website:

...

Dead. Why?

```
$ kubectl get pods
```

Or even better, let's use a describe to get a better idea of what is wrong:

```
$ kubectl describe pod $foo

Events:
 Type     Reason            Age                From               Message
 ----     ------            ----               ----               -------
 Warning  FailedScheduling  12s (x13 over 2m)  default-scheduler  PersistentVolumeClaim is not bound: "my-wordpress-wordpress" (repeated 3 times)
```

And now let's check why our PersistentVolumeClaim (PVC) is not binding:

```
$ kubectl describe pvc my-wordpress-wordpress

Events:
 Type     Reason              Age                From                         Message
 ----     ------              ----               ----                         -------
 Warning  ProvisioningFailed  11s (x15 over 3m)  persistentvolume-controller  Failed to provision volume with StorageClass "gp2": invalid AccessModes [ReadWriteMany]: only AccessModes [ReadWriteOnce] are supported
```

Well, EBS volumes can only be ReadWriteOnce, so we need to replace it with something that can support ReadWriteMany.

## 2-5: Clean up our wordpress install:

Let's clean up this wordpress and go again.

```
$ helm del --purge my-wordpress
```

We can use an NFS server to create ReadWriteMany PVs that can be mounted in multiple pods

```
$ helm install --name my-nfs stable/nfs-server-provisioner
```

Now that we have the NFS provisioner created, we can use it to give us a multiple replica WordPress site.

```
$ helm install --name my-wordpress --set wordpressBlogName="Andy's blog",mariadb.enabled=false,externalDatabase.host=my-wordpress-db-mariadb,externalDatabase.password=devopsdays,externalDatabase.database=devopsdays,externalDatabase.port=3306,persistence.storageClass=nfs stable/wordpress
```

Let's confirm that our new PVC is using nfs:

```
$ kubectl get pvc
NAME                                    STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-my-wordpress-db-mariadb-master-0   Bound     pvc-d2415512-6e58-11e8-994e-0abdad16821e   8Gi        RWO            gp2            6d
data-my-wordpress-db-mariadb-slave-0    Bound     pvc-d246f805-6e58-11e8-994e-0abdad16821e   8Gi        RWO            gp2            6d
data-my-wordpress-db-mariadb-slave-1    Bound     pvc-f1b6e9be-6e58-11e8-994e-0abdad16821e   8Gi        RWO            gp2            6d
my-wordpress-wordpress                  Bound     pvc-f80012f7-732b-11e8-926e-0a33561ebb8c   10Gi       RWO            nfs            52s
```

## 2-6: Increase replica count

Now that we have our PVC ready to go, we can now scale up our wordpress website to 3 replicas:

```
$ kubectl scale deployment my-wordpress-wordpress --replicas=3
```

Now let's confirm our replicas are coming up:

```
$ kubectl get pods -o wide

NAME                                      READY     STATUS    RESTARTS   AGE       IP            NODE
my-nfs-nfs-server-provisioner-0           1/1       Running   0          3m        100.96.2.2    ip-172-20-40-196.eu-west-1.compute.internal
my-wordpress-db-mariadb-master-0          1/1       Running   0          1h        100.96.1.8    ip-172-20-43-243.eu-west-1.compute.internal
my-wordpress-db-mariadb-slave-0           1/1       Running   0          1h        100.96.1.6    ip-172-20-43-243.eu-west-1.compute.internal
my-wordpress-db-mariadb-slave-1           1/1       Running   0          1h        100.96.1.9    ip-172-20-43-243.eu-west-1.compute.internal
my-wordpress-wordpress-66b7d5b545-cvzqd   0/1       Running   0          31s       100.96.1.10   ip-172-20-43-243.eu-west-1.compute.internal
my-wordpress-wordpress-66b7d5b545-r7cpq   0/1       Running   0          31s       100.96.2.4    ip-172-20-40-196.eu-west-1.compute.internal
my-wordpress-wordpress-66b7d5b545-v6cg2   1/1       Running   0          2m        100.96.2.3    ip-172-20-40-196.eu-west-1.compute.internal
```

We can see our replicas are spread across several nodes, which should prevent all of them being taken out in the case of a node failure.

Does this make us fully HA? What alternatives could we use?

## Cleanup

Please run: 

```
./workshop.sh workshop2-cleanup
```
