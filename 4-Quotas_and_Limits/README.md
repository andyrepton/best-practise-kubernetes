# Workshop 4: Quotas and Limits

## 4.1: What is a quota and how is it different to Requests and Limits?

### Requests:
- Pod: "I want this amount of CPU/RAM"
- Node: "Yeah, I don't have that much"
- Pod: :(

Pod will remain pending

### Limits:
- Pod: I'm a poorly written Java app and I want RAM YOLO
- Node: Yeah, you're only allowed 512Mb of RAM. Buh bye
- Pod: Nooooooooooo

Pod is restarted

### Quotas:
- User: I'd like 8CPU Cores for my Pod please
- Admin: No. *Grumpy cat*

*** Watch as Andy creates hundreds of replicas on stage and (potentially) kills his cluster ***


## 4.2: Using quotas to limit usage on a namespace

First, let's create our namespace:
```
kubectl create namespace devopsdays-demo
```

We want to prevent a mistake or a malicious user from overwhelming the cluster. For this, we use quotas. An example is in this directory.

```
$ kubectl create -f quota.yml
```

Now try and create 100 replicas:

```
$ kubectl -n devopsdays-demo run nginx --image=nginx:stable --replicas=100
```

If we now check the namespace for our pods:

```
$ kubectl -n devopsdays-demo get pods
No resources found.

$ kubectl -n devopsdays-demo get deploy
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx     100       0         0            0           41s
```

Let's see why:

```
$ kubectl -n devopsdays-demo describe rs 
Warning  FailedCreate  1m                replicaset-controller  Error creating: pods "nginx-7cc8949494-pm68x" is forbidden: failed quota: devopsdays-demo: must specify limits.cpu,limits.memory,requests.cpu,requests.memory
```

Quotas not only set the total limits, they also enforce that people have to set requests and limits on their deployments, pods etc.

Let's clean up that deployment:
```
$ kubectl -n devopsdays-demo delete deployment nginx
```

## 4.3: Adding limits and requests

Now let's try creating 10 replicas, this time adding our requests and our limits to our run command:

```
$ kubectl -n devopsdays-demo run nginx --image=nginx:stable --requests='cpu=100m,memory=256Mi' --limits='cpu=150m,memory=512Mi' --replicas=10
deployment "nginx" created
```

Now if we check once again, only 4 have started:

```
$ kubectl -n devopsdays-demo get pods -o wide
NAME                     READY     STATUS    RESTARTS   AGE       IP             NODE
nginx-6c788db6bd-2qf8n   1/1       Running   0          3s        100.96.1.186   ip-172-20-57-78.eu-west-1.compute.internal
nginx-6c788db6bd-c6w46   1/1       Running   0          3s        100.96.2.161   ip-172-20-59-214.eu-west-1.compute.internal
nginx-6c788db6bd-dkksk   1/1       Running   0          3s        100.96.1.185   ip-172-20-57-78.eu-west-1.compute.internal
nginx-6c788db6bd-lxh2w   1/1       Running   0          3s        100.96.1.184   ip-172-20-57-78.eu-west-1.compute.internal
```

If we now check the replicaset once again:

```
$ kubectl -n devopsdays-demo describe replicasets
Warning  FailedCreate      1m                replicaset-controller  Error creating: pods "nginx-6c788db6bd-cqt4r" is forbidden: exceeded quota: devopsdays-demo, requested: limits.memory=512Mi, used: limits.memory=2Gi, limited: limits.memory=2Gi
```

Using quotas, we can limit on a per namespace level the resource usage allowed. For example, you could allow a Production namespace a higher usage limit than the development one.
