# 使用CephFS作为分布式存储

- 在使用CephFS之前，你需要知道Ceph集群的以下信息
  - *monitors*: Ceph集群的monitor节点地址
  - *path*: 你有权限的CephFS上的目录，默认为根目录
  - *secret*: cephfs的secret，通常会作为Kubernetes的secret保存在集群，
  也可以参考[cephfs-secret.yaml](./cephfs-secret.yaml)自行提交
- 使用方法
  1. 查看是否已存在ceph-secret,若看到已下输入说明已创建过ceph-secret，可跳过步骤2
  ```bash
  >kubectl get secret
  NAME            TYPE          DATA          AGE
  ceph-secret     Opaque        1             19m
  ```
  1. 添加ceph-secret,从管理获取ceph集群的secret,并替换下面命令中的`<ceph-secret>`变量
  ```bash
  echo -n "<ceph-secret>" | base64
  ```
  将上面命令输出的base64编码替换`ceph-secret.yaml`中的<key>
  ```yml
  apiVersion: v1
  kind: Secret
  metadata:
      name: ceph-secret
  data:
      key: <key>
  ```
  ```bash
  kubectl create -f ceph-secret.yaml
  ```
  1. 参考[pod.yaml](./pod.yaml)提交pod
  ```bash
  kubectl create -f pod.yaml
  ```
