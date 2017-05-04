# 安装kubectl
## 下载客户端
 根据操作系统下载kubectl命令行客户端：[OS X](http://pan.baidu.com/s/1o87B4eA), [Linux](http://pan.baidu.com/s/1kVoKLNL), [Windows](http://pan.baidu.com/s/1dE6rFKP)，安装到系统环境变量（$PATH）下以方便访问。

## 配置Kubectl

1. 配置不带TLS认证的kubectl
将以下内容保存在本机`~/.kube/config`文件中，并按步骤修改文件：
  ```yaml
  apiVersion: v1
  clusters:
  - cluster:
      server: http://[server]
    name: paddle
  contexts:
  - context:
      cluster: paddle
      user: default-admin
    name: default-system
  current-context: default-system
  kind: Config
  preferences: {}
  ```
1. 配置带TLS认证的kubectl
将以下内容保存在本机`~/.kube/config`文件中，并按步骤修改文件:
  ```yaml
  apiVersion: v1
  clusters:
  - cluster:
      certificate-authority: [key fie path]/ca.pem
      server: http://[server]
    name: paddle
  contexts:
  - context:
      cluster: paddle
      user: default-admin
      namespace: [namespace]
    name: default-system
  current-context: default-system
  kind: Config
  preferences: {}
  users:
  - name: default-admin
    user:
      client-certificate: [key file path]/[username].pem
      client-key: [key file path]/[username]-key.pem
  ```

  - 修改`[username]`为系统分配的用户名.
  - 修改`[key file path]`为本地存储tls key文件的目录(绝对路径).
  - 修改`[server]`为kubernetes集群中apiserver的地址.
  - 修改`[namespace]`为系统分配给您的namespace，通常和`[username]`相同。

1. 测试连接到集群
  ```bash
  $ kubectl cluster-info
  ```
  执行以上命令，如果没有报错信息，并有集群基本信息返回则客户端配置成功。此时也可以执行`kubectl version`来查看客户端和服务端的Kubernetes版本。
