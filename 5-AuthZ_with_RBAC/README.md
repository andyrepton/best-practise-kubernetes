# Workshop 5: AuthZ with RBAC. Challenge time!

Now we know about locking down the namespace with quotas and limits, let's prevent people from simply creating more namespaces:

## What is RBAC
RBAC is Role Based Access Control, and it allows you to create fine grained permissions for users at the Cluster or the Namespace level.

RBAC requires Roles (effectively defining the permissions), and RoleBindings apply those to Users.

As an example, if we needed to let the managers see what was going on, but we didn't want them to edit things, we would start by creating the role:

```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: read-only-pods-deploy
rules:
- apiGroups: [""]
  resources: ["pods", "deployments"]
  verbs: ["get", "watch", "list"]
```
This only permits the GET, WATCH or LIST verbs, together they comprise of a general 'Read only' grouping.

And then use the RoleBinding to bind it to the Group 'managers' at the Namespace level:

```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-only-pods-deploy
  namespace: default
subjects:
- kind: Group
  name: managers
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: yvo
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: read-only-pods-deploy
  apiGroup: rbac.authorization.k8s.io
```

I added Yvo in there too. These files are in the same repo as this README.

## RBAC Challenge: Give Andy restricted access

In each of your clusters there is an additional user, named 'devopsandy'. The challenge is:

1. Using your namespace from Workshop 4 (devopsdays-demo), with the quota 
2. Allow the 'devopsandy' user full permissions to create, edit, view and delete anything inside the 'devopsdays-demo' namespace
3. Not permit access to any other namespace or any cluster resources

Raise your hand or call out when you've done it and Andy will test from the stage

(Hint: there are a couple of examples in this folder you can use as templates)
