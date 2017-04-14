# A Practical and Comprehensive Guide to Kubernetes

This trial covers
[Kubernetes 101](http://kubernetes.io/docs/user-guide/walkthrough/),
[Kubernetes 201](http://kubernetes.io/docs/user-guide/walkthrough/k8s201/),
and the
[Guestbook example](https://github.com/kubernetes/kubernetes/blob/release-1.2/examples/guestbook/README.md),
but interleaved more explanation to Kubernetes concepts and internals.

Kubernetes concepts covered in this document include:

1. cluster
1. nodes (and node IP)
1. pods (and pod IP)
1. labels
1. replication controller (or RC for short)
1. service
1. deployment

To run this trial, we need a Kubernetes cluster.  We can follow
https://github.com/k8sp/vagrant-coreos to create one running on a
Vagrant cluster of CoreOS virtual machines.

## The Cluster

Now we have a Kubernetes cluster running.  To get some information about it, we run `kubectl cluster-info`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl cluster-info
Kubernetes master is running at https://172.17.4.101:443
Heapster is running at https://172.17.4.101:443/api/v1/proxy/namespaces/kube-system/services/heapster
KubeDNS is running at https://172.17.4.101:443/api/v1/proxy/namespaces/kube-system/services/kube-dns
```

where `172.17.4.101` is the IP address of a virtual machine (or,
*node*) that runs the Kubernetes master piece (or, *control node*).


## Nodes

In additional to the control node, there are other nodes in the
cluster.  To show them, we use `kubectl get nodes`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get nodes
NAME           STATUS                     AGE
172.17.4.101   Ready,SchedulingDisabled   5h
172.17.4.201   Ready                      5h
```

Each node has an IP address, simply because each virtual machine has an IP address.
When we create this virtual machine cluster, we specify node IPs in
Vagrant file.  If the Kubernetes cluster is created using Vagrant, we
should be able to `ping 172.17.4.101` or `ping 172.17.4.201` on the
host, just as we ping virtual machine from host.

Please be aware that *node IP* is different from *pod IP*.  In order
to know more about *pod IP*, let's create some pods.


## Pods

We can create a pod by `kubectl create -f pod_description.yaml`.  An
example pod description YAML file is
[pod_nginx.yaml](./pod_nginx.yaml):

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
```

Here is the way to create a pod from `pod_nginx.yaml`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f pod_nginx.yaml 
pod "nginx" created
```

Usually, it takes sometime for Kubernetes to download the Docker image
of the pod.  So the initial status of the pod is `ContainerCreating`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pod
NAME      READY     STATUS              RESTARTS   AGE
nginx     0/1       ContainerCreating   0          3s
```

By giving `-o wide` to `kubectl get pod`, we can see the IP of the
node on which the pod is running:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pod -o wide
NAME      READY     STATUS    RESTARTS   AGE       NODE
nginx     1/1       Running   0          15s       172.17.4.201
```

It is important to know that each pod in a Kubernetes cluster is
assigned an IP in a flat shared networking namespace.  This allows for
a clean network model where Pods, from a networking perspective, can
be treated much like virtual machines or physical
hosts. (c.f. https://coreos.com/kubernetes/docs/latest/kubernetes-networking.html)

To get the pod IP, we provide a customized template to the `-o` flag:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pod nginx -o go-template={{.status.podIP}}
10.2.75.4
```

Note that pod IPs are not visible outside of the Kubernetes.  For
above example, if we want to access the nginx pod, we need to log into
a node:

```
yi@WangYis-iMac:~/work/k8sp/vagrant-coreos/coreos-kubernetes/multi-node/vagrant (master)*$ vagrant ssh w1 -c "curl http://10.2.75.4"
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</body>
</html>
Connection to 127.0.0.1 closed.
```

How if we want to be able to access the pod from outside the cluster?
We need to create a *service* around the pod, because *service* is a
Kubernetes object for exposing pods to the outside world.  But before
getting into services, we need to understand *labels* and *replication
controller*.


## Label

For tolerance, a service is usually composed of a group of redundant
pods.  How can we select such a group?  Pod name doesn't work, because
each pod has its unique name.  So here comes *labels*.  We can assign
multiple pods the same label, and select these pods as a group by
using the label.

[`pod_nginx_with_label.yaml`](./pod_nginx_with_label.yaml) shows how
to define a label `app: nginx` in addition to `pod_nginx.yaml`:

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:       # <-
    app: nginx  # <-
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
```

Because `pod_nginx_with_label.yaml` also defines a pod named `nginx`
as `pod_nginx.yaml` does, we need to delete the pod created from
`pod_nginx.yaml` before we create a new pod from
`pod_nginx_with_label.yaml`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl delete pod nginx
pod "nginx" deleted
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f pod_nginx_with_label.yaml 
pod "nginx" created
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
NAME      READY     STATUS              RESTARTS   AGE
nginx     0/1       ContainerCreating   0          6s
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods -l app=nginx
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          16s
```

Note again that we cannot create two pods with the same name.
```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f pod_nginx.yaml 
Error from server: error when creating "pod_nginx.yaml": pods "nginx" already exists
```


## Replication Controllers

How if we want to create 10 pods, all running nginx, so to create a
service?  We can create them one-by-one manually, each with its unique
name.  But a smarter way is to use *replication controller*.

An example replication controller (RC for short) is
[`rc_nginx.yaml`](./rc_nginx.yaml):

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-controller
spec:
  replicas: 2
  # selector identifies the set of Pods that this
  # replication controller is responsible for managing
  selector:
    app: nginx
  # podTemplate defines the 'cookie cutter' used for creating
  # new pods when necessary
  template:
    metadata:
      labels:
        # Important: these labels need to match the selector above
        # The api server enforces this constraint.
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

`rc_nginx.yaml` creates an rc named `nginx-controller` that wants 2
replicas of nginx pods with label `app: nginx`.  Note that
`rc_nginx.yaml` contains a "template" section which is the template of
pod definition.  The template in `rc_nginx.yaml` looks very similar to
the content of [pod_nginx.yaml](./pod_nginx.yaml).

Remember that we already have one pod with label `app: nginx` running,

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          25m
```

so, when we create this rc, Kubernetes starts only one new pod:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f rc_nginx.yaml 
replicationcontroller "nginx-controller" created
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
NAME                     READY     STATUS              RESTARTS   AGE
nginx                    1/1       Running             0          25m
nginx-controller-58t5s   0/1       ContainerCreating   0          5s
```

`kubectl get rc` lists this rc:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get rc
NAME               DESIRED   CURRENT   AGE
nginx-controller   2         2         36s
```

Deleting this rc deletes all two pods, including the one we created
manually from `pod_nginx.yaml`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl delete rc nginx-controller
replicationcontroller "nginx-controller" deleted
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
```

## Services

Finally we have a replicated set of nginx pods, we can wrap them up as
a service now.  [`service_nginx.yaml`](./service_nginx.yaml) shows how
to do this:

```
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  ports:
  - port: 8000 # the port that this service should serve on
    # the container on each pod to connect to, can be a name
    # (e.g. 'www') or a number (e.g. 80)
    targetPort: 80
    protocol: TCP
  # just like the selector in the replication controller,
  # but this time it identifies the set of pods to load balance
  # traffic to.
  selector:
    app: nginx
```

Remember that we already have an RC of two nginx pods running.  All
these pods have label `app: nginx`.  So the following command wraps
these pods up:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f service_nginx.yaml 
service "nginx-service" created
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
nginx-controller-0xc3c   1/1       Running   0          23m
nginx-controller-oii7h   1/1       Running   0          23m
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get rc
NAME               DESIRED   CURRENT   AGE
nginx-controller   2         2         24m
```

Deleting the service doesn't affect the RC and pods:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl delete service nginx-service
service "nginx-service" deleted
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
nginx-controller-0xc3c   1/1       Running   0          24m
nginx-controller-oii7h   1/1       Running   0          24m
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get rc
NAME               DESIRED   CURRENT   AGE
nginx-controller   2         2         24m
```

If we want to clean up, we need to explicitly delete the RC, then the
pods are deleted as well:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl delete rc nginx-controller
replicationcontroller "nginx-controller" deleted
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
```

When there are no pods with label `app: nginx` running, we can still
create a service, but it doesn't' include any pods yet:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f service_nginx.yaml 
service "nginx-service" created
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get rc
```

Now we can create pods with service-wanted label `app: nginx`:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl create -f rc_nginx.yaml 
replicationcontroller "nginx-controller" created
```

Then we check that the service noticed and selected these pods:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl describe service
Name:			kubernetes
  ....
Name:			nginx-service
  ....
Endpoints:		10.2.75.4:80,10.2.75.5:80
  ....
  ```

Noticed the two endpoints?  They are actually the newly started two
nginx pods.  To confirm this, we check the pod IPs of these two pods:

```
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pods -l app=nginx -o wide
NAME                     READY     STATUS    RESTARTS   AGE       NODE
nginx-controller-pioas   1/1       Running   0          8m        172.17.4.201
nginx-controller-s9q1l   1/1       Running   0          8m        172.17.4.201
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pod nginx-controller-pioas -o go-template={{.status.podIP}}
10.2.75.4
yi@WangYis-iMac:~/work/k8sp/kubernetes $ kubectl get pod nginx-controller-s9q1l -o go-template={{.status.podIP}}
10.2.75.5
```

The two pods have pod IPs `10.2.75.4` and `10.2.75.5`, which are those
shown as endpoints of service `nginx-service`.


## Load Balancer

By this time, you might want to check if we can access the nginx
service from outside of the Kubernetes cluster.  Unfortunately, we
cannot, because we have been doing above steps in a Vagrant cluster,
which doesn't provide Kubernetes a *load balancer*, which expose
services to the outside world.

*Load balancer* is one of the three ways that Kubernetes expose
services.  The other two are *ClusterIP* and *NodePort*.  As explained
in http://rafabene.com/2015/11/11/how-expose-kubernetes-services/:

1. `ClusterIP`: use a cluster-internal IP only - this is the default
   and is discussed above. Choosing this value means that you want
   this service to be reachable only from inside of the cluster.
1. `NodePort` : on top of having a cluster-internal IP, expose the
   service on a port on each node of the cluster (the same port on
   each node). You’ll be able to contact the service on any :NodePort
   address.
1. `LoadBalancer`: on top of having a cluster-internal IP and exposing
   service on a NodePort also, ask the cloud provider for a load
   balancer which forwards to the Service exposed as a :NodePort for
   each Node.

We can choose among the three ways by setting the `ServiceType`
attribute in the YAML file.

If we run above steps on GKE or AWS, we can choose `LoadBalancer`,
since GKE and AWS provides load balancers.  Given that we have been
using Vagrant cluster, we can choose `NodePort`.  For more details,
please refer to
http://rafabene.com/2015/11/11/how-expose-kubernetes-services/:.


## Networking

You might be wondering about how all these networking related things,
node IP, pod IP, external IP, work.
https://coreos.com/kubernetes/docs/latest/kubernetes-networking.html
explained this:

To understand load balancer, we need to understand the types of
Kubernetes communication:

1. *Container-to-Container Communication*: Kubernetes assigns an IP
   addres to each pod, therefore containers within a pod are
   identified with `localhost` and different ports.
1. *Pod-to-Pod Communication*: Each Pod in a Kubernetes cluster is
   assigned an IP in a flat shared networking namespace.  We do not
   need to explicitly create links between pods and we almost never
   need to deal with mapping container ports to host ports.  This
   creates a clean, backwards-compatible model where pods can be
   treated much like VMs or physical hosts from the perspectives of
   port allocation, naming, service discovery, load balancing,
   application configuration, and migration.
1. *Pod-to-Service Communication*: Services are implemented by
   assigning Virtual IPs which clients can access and are
   transparently proxied to the Pods grouped by that service. Requests
   to the Service IPs are intercepted by a kube-proxy process running
   on all hosts, which is then responsible for routing to the correct
   Pod.
1. *External-to-Internal Communication:* Accessing services from
   outside the cluster is generally implemented by configuring
   external load balancers which target all nodes in the cluster. Once
   traffic arrives at a node, it is routed to the correct Service
   backends via the kube-proxy.  See Kubernetes Networking for more
   detailed information on the Kubernetes network model and
   motivation.

More about Kubernetes networking is at [here](./networking/README.md).

## Deployment

Above examples show how to create pods using RC and how to wrap
created pods into a service.  In practice, we rarely use RC directly
to create pods; instead, we use *deployment*.  This is because we want
*deployment* to take care of the roll-out and rollback affair.

To be continued.

<!--  LocalWords:  Guestbook kubectl Heapster KubeDNS yaml nginx ssh
 -->
<!--  LocalWords:  SchedulingDisabled apiVersion metadata podIP html
 -->
<!--  LocalWords:  containerPort ContainerCreating DOCTYPE app md rc
 -->
<!--  LocalWords:  ReplicationController podTemplate api www NodePort
 -->
<!--  LocalWords:  replicationcontroller targetPort kubernetes GKE
 -->
<!--  LocalWords:  ClusterIP LoadBalancer ServiceType AWS kube
 -->
