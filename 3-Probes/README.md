# Workshop 3: Readiness and Liveness Probes

## 3.1: kubectl run and port-forward
I've made us an image we can use:

```
$ kubectl run devopsdays --image sethkarlo/nginx:dod-first
```

This should start up quickly, and with this we can get the pod name and port-forward to it:

```
$ kubectl get pods
```

Using the pod name, now open a port forward:

```
$ k port-forward devopsdays-7f9bdcc9c5-nm7ch 8080:80
```

And in your browser we can open http://127.0.0.1:8080

## 3.2: Upgrade using a patch:

Great, now let's move onto our second image, dod-second:

```
$ kubectl patch deployment devopsdays -p '{"spec":{"template":{"spec":{"containers":[{"name":"devopsdays","image":"sethkarlo/nginx:dod-second"}]}}}}'
```

Now let's redo our port-forward (patching the deployment will have changed the pod name):

```
$ kubectl get pods
NAME                                      READY     STATUS        RESTARTS   AGE
devopsdays-86945768c-49pvf                1/1       Running       0          18s

$ kubectl port-forward devopsdays-86945768c-49pvf 8080:80
Forwarding from 127.0.0.1:8080 -> 80
Handling connection for 8080
```

Now browse to http://127.0.0.1:8080 and you should see our second website

...

Or not. Let's look at the logs and see why this hasn't come up

```
$ kubectl logs devopsdays-86945768c-49pvf
```

## 3.3 Adding a readiness probe to the deployment:

```
$ kubectl apply -f readiness_patch.yml
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
deployment "devopsdays" configured
```

We should now see that our pod remains unready, and so will not get added to any services:

```
$ kubectl get pods
NAME                                      READY     STATUS        RESTARTS   AGE
devopsdays-b5bd6ff4d-nxgrr                0/1       Running       0          40s
```

Now let's add a liveness probe:

```
$ kubectl apply -f liveness_patch.yml
```

And we can port-forward once again to see our final image
