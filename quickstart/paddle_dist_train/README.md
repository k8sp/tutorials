# 一个运行Paddle Job的例子

[PaddlePaddle](https://github.com/PaddlePaddle/Paddle) 是起源于百度的开源深度学习平台。它是简单易用的：你可以通过简单的十数行配置搭建经典的神经网络模型；它也是高效强大的：PaddlePaddle可以支撑复杂集群环境下超大模型的训练，令你受益于深度学习的前沿成果。在百度内部，已经有大量产品线使用了基于PaddlePaddle的深度学习技术。

您可以在[PaddlePaddle官方文档](http://www.paddlepaddle.org/doc_cn/)或者基于PaddlePaddle的[深度学习入门](https://github.com/PaddlePaddle/book)教程来了解深度学习和如何使用PaddlePaddle。本文将重点介绍，如何快速的在Kubernetes集群上运行起来一个Paddle的神经网络训练任务，并获得输出结果。

本文中的例子使用了 https://github.com/PaddlePaddle/Paddle/tree/develop/demo/quick_start 的示例程序trainer_config.lr.py，其使用Amazon公开的对3C类商品的评价文本数据，训练一个简单的神经网络完成对评价情感的预测，推断评价为正面评价还是负面评价

## 环境准备

- 配置Kubernetes集群客户端

  你可以访问的Kubernetes集群可以是一个本地的虚拟机测试集群(如[*minikube*](https://kubernetes.io/docs/getting-started-guides/minikube/))，也可以是您在[*AWS*](https://kubernetes.io/docs/getting-started-guides/aws/)上搭建的集群，也可以是您的公司或者学校为您提供的Kubernetes集群。连接到这些集群都需要`kubectl`的命令行客户端、集群的连接地址、账户（密钥）。

  如果您还没有配置过kubectl,请按[此步骤](../../configure_kubectl.md)进行配置。

- 安装Docker

  根据[这篇文档](../../container/README.md)在本地安装Docker。如果集群没有提供私有的Docker registry，可以使用Docker官方提供的[Docker Hub](https://hub.docker.com)来存储镜像，您需要先注册账号,并通过`docker login <username>`命令执行登录，以便后续上传镜像使用。

## 使用PaddlePaddle Docker镜像构建一个集群任务
- 准备训练数据
  在挂载了GlusterFS Volume的服务器上执行以下命令:
  ```bash
  cd <GlusterFS Mount Path>
  DATA_PATH=<your file path> JOB_NAME=<dist train job name> TRAINER_COUNT=<trainer count> ./get_data.sh
  ```
  - DATA_PATH 管理员为你分配的在GlusterFS Volume上的目录
  - JOB_NAME 本次集群训练的名字，需要保证在运行的job名字唯一
  - TRAINER_COUNT trainer进程数量

  **注意**:由于每个trainer进程读取一个数据片，所以trainer进程数量要和数据分片个数保持一致。

  Example:
  ```bash
  $ cd /mnt/gfs_vol/xxx
  $ DATA_PATH=$PWD JOB_NAME=paddle-cluster-job TRAINER_COUNT=3 ./get_data.sh
  ```

  执行成功后的目录结构大概为：
  ```bash
  .
  ./get_data.sh
  ./gluster-paddle-job
  ./gluster-paddle-job/.Done
  ./gluster-paddle-job/2
  ./gluster-paddle-job/2/data
    ...
  ./gluster-paddle-job/1
  ./gluster-paddle-job/1/data
    ...
  ./gluster-paddle-job/0
  ./gluster-paddle-job/0/data
    ...
  ```
- 构建运行PaddlePaddle任务的docker镜像

  本文中使用quick_start做为样例程序，您可以修改Dockerfile，打包自己的Docker Image并push到Docker Registry
  ```bash
  docker build -t [yourepo]/paddle_k8s_quickstart .
  # push到共有的dockerhub或私有registry
  # 可以使Kubernetes各个节点访问到这个镜像
  docker push [yourepo]/paddle_k8s_quickstart
  ```
- [quickstart.yaml](./quickstart.yaml)是提交quick_start分布式训练任务的一个样例配置.

  需要经常修改的参数说明：
  - `.metadata.name` 集群训练的Job名字，同一个namespace下不可以出现重名的情况
  - `.spec.template.metadata.name` 和 `metadata.name` 保持一致即可
  - `.spec.parallelism` 并发执行的Pod数量，通常和trainer进程数保持一致即可
  - `.spec.template.spec.volumes[0].gluterfs.path` 由管理员分配给您在GlusterFS的Volume
  - `.spec.template.spec.containers[0].image` 上一步中打包并push的Docker Image
  - `.spec.template.spec.containers[0].env` Pod执行时加载的环境变量
    - `JOB_NAME` 集群训练的Job名字，和`metadata.name`保持一致即可
    - `JOB_PATH` Pod Mount的GlusterFS Volume路径，由于同一个Volume可能会被多个人同时使用，所以这个路径通常是一个属于自己的路径，例如Mount到Pod的路径是`/mnt/glusterfs`，您使用的路径可以是`/mnt/glusterfs/user0`。
    - `TRAINER_PACKAGE` Docker Image中程序包的路径，这会在上一步的Dockerfile指定,例如[这里](./Dockerfile#L3),路径是`/root/quick_start`.
    - `TRAINER_COUNT` trainer进程数量

- 提交任务和监控任务状态，如果Pod显示`RUNNING`状态表示正在运行，如果显示`Completed`表示执行成功

  ```bash
  # 提交任务
  kubectl create -f quickstart.yaml
  # 查看提交的任务
  kubectl get jobs
  # 查看任务启动的pod
  kubectl get pods -a
  # 查看任务的某个pod的运行日志
  kubectl logs [PodID]
  # 查看某个Pod的运行情况，如果出现非RUNNING和Completed的状态可以通过这个命令查看原因
  kubectl describe pod [PodID]
  ```
