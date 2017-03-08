# 一个运行Paddle Job的例子

[PaddlePaddle](https://github.com/PaddlePaddle/Paddle) 是起源于百度的开源深度学习平台。它是简单易用的：你可以通过简单的十数行配置搭建经典的神经网络模型；它也是高效强大的：PaddlePaddle可以支撑复杂集群环境下超大模型的训练，令你受益于深度学习的前沿成果。在百度内部，已经有大量产品线使用了基于PaddlePaddle的深度学习技术。

您可以在[PaddlePaddle官方文档](http://www.paddlepaddle.org/doc_cn/)或者基于PaddlePaddle的[深度学习入门](https://github.com/PaddlePaddle/book)教程来了解深度学习和如何使用PaddlePaddle。本文将重点介绍，如何快速的在Kubernetes集群上运行起来一个Paddle的神经网络训练任务，并获得输出结果。

## 连接到你的Kubernetes集群

你可以访问的Kubernetes集群可以是一个本地的虚拟机测试集群(如[*minikube*](https://kubernetes.io/docs/getting-started-guides/minikube/))，也可以是您在[*AWS*](https://kubernetes.io/docs/getting-started-guides/aws/)上搭建的集群，也可以是您的公司或者学校为您提供的Kubernetes集群。连接到这些集群都需要`kubectl`的命令行客户端、集群的连接地址、账户（密钥）。

1. 获得`kubectl`，下载完成后将其移动到环境变量`PATH`所在的目录下以方便使用：

  ```bash
  # OS X
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl

  # Linux
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

  # Windows
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/windows/amd64/kubectl.exe
  ```

2. 配置集群连接地址，编辑`~/.kube/config`文件，修改`server: https://192.168.99.100:8443`地址为要连接到的地址。可以使用IP和域名。***注意***要正确填写是http还是https的地址，https地址通常要求配置SSL认证所需要的证书信息。

  ```yaml
  apiVersion: v1
  clusters:
  - cluster:
      certificate-authority: /Users/wuyi/.minikube/ca.crt
      server: https://192.168.99.100:8443
    name: minikube
  contexts:
  - context:
      cluster: minikube
      namespace: [user namespace]
      user: minikube
    name: minikube
  current-context: minikube
  kind: Config
  preferences: {}
  users:
  - name: minikube
    user:
      client-certificate: /Users/wuyi/.minikube/[user].crt
      client-key: /Users/wuyi/.minikube/[user].key
  ```

3. 配置账户和密钥，编辑`~/.kube/config`配置文件，配置`certificate-authority: /Path/to/ca.crt`为Kubernetes集群管理员提供的根证书（或名为`ca.pem`），然后在`users:`配置段中增加用户的配置项`client-certificate`，包括公钥`[user].key`和证书`[user].crt`(或`[user].pem`)。配置`namespace: [user namespace]`到管理员分配的空间。

  ***注***: `[user]`是指Kubernetes集群管理员为您分配的账户名

4. 测试连接到集群
  ```bash
  $ kubectl cluster-info
  ```
  执行以上命令，如果没有报错信息，并有集群基本信息返回则客户端配置成功。此时也可以执行`kubectl version`来查看客户端和服务端的Kubernetes版本。

## 使用Paddle构建一个集群任务
任务使用了 https://github.com/PaddlePaddle/Paddle/tree/develop/demo/quick_start 的示例程序trainer_config.lr.py，其使用Amazon公开的对3C类商品的评价文本数据，训练一个简单的神经网络完成对评价情感的预测，推断评价为正面评价还是负面评价

1. 构建运行Paddle任务的docker镜像

  ```bash
  cd quickstart
  docker build . -t [yourepo]/paddle:k8s_quickstart
  # push到共有的dockerhub或私有registry
  # 可以使Kubernetes各个节点访问到这个镜像
  docker push [yourepo]/paddle:k8s_quickstart
  ```
2. 编辑Kubernetes运行的编排文件，修改`image`指向上一部push的镜像的地址，并根据需要修改环境变量的配置

  ```bash
  vim quickstart.yaml
  ```
3. 提交任务和监控任务状态，如果Pod显示`RUNNING`状态表示正在运行，如果显示`Completed`表示执行成功

  ```bash
  # 如果没有namespace则创建paddle namespace
  kubectl create namespace paddle
  kubectl --namespace=paddle create -f quickstart.yaml
  # 查看提交的任务
  kubectl --namespace=paddle get jobs
  # 查看任务启动的pod
  kubectl --namespace=paddle get pods -a
  # 查看任务的某个pod的运行日志
  kubectl --namespace=paddle logs [PodID]
  ```
