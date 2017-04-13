# 一个运行Paddle Job的例子

[PaddlePaddle](https://github.com/PaddlePaddle/Paddle) 是起源于百度的开源深度学习平台。它是简单易用的：你可以通过简单的十数行配置搭建经典的神经网络模型；它也是高效强大的：PaddlePaddle可以支撑复杂集群环境下超大模型的训练，令你受益于深度学习的前沿成果。在百度内部，已经有大量产品线使用了基于PaddlePaddle的深度学习技术。

您可以在[PaddlePaddle官方文档](http://www.paddlepaddle.org/doc_cn/)或者基于PaddlePaddle的[深度学习入门](https://github.com/PaddlePaddle/book)教程来了解深度学习和如何使用PaddlePaddle。本文将重点介绍，如何快速的在Kubernetes集群上运行起来一个Paddle的神经网络训练任务，并获得输出结果。

## 连接到你的Kubernetes集群

你可以访问的Kubernetes集群可以是一个本地的虚拟机测试集群(如[*minikube*](https://kubernetes.io/docs/getting-started-guides/minikube/))，也可以是您在[*AWS*](https://kubernetes.io/docs/getting-started-guides/aws/)上搭建的集群，也可以是您的公司或者学校为您提供的Kubernetes集群。连接到这些集群都需要`kubectl`的命令行客户端、集群的连接地址、账户（密钥）。

- 如果您还没有配置过kubectl,请按[此步骤](../../configure_kubectl.md)进行配置。

## 使用Paddle构建一个集群任务
任务使用了 https://github.com/PaddlePaddle/Paddle/tree/develop/demo/quick_start 的示例程序trainer_config.lr.py，其使用Amazon公开的对3C类商品的评价文本数据，训练一个简单的神经网络完成对评价情感的预测，推断评价为正面评价还是负面评价

1. 准备训练数据

  在挂载了分布式存储volume的服务器上执行以下命令：
  ```bash
  DATA_PATH=<DATA_ROOT> JOB_NAME=<job-name> SPLIT_COUNT=<trainer-count> ./getdata.sh
  ```
  - DATA_PATH 为GlusterFS挂载在服务器上的目录
  - JOB_NAME 为每个集群训练的名字
  - SPLIT_COUNT 根据需要将数据切分为多份

1. 基于PaddlePaddle生产环境镜像构建PaddlePaddle分布式训练
  - 本文中使用quick_start做为样例程序，你可以修改Dockerfile，打包自己的Docker Image并push到Docker Registry
  ```bash
  docker build -t paddlepaddle/paddle_k8s:quick_start .
  docker push paddlepaddle/paddle_k8s:quick_start
  ```

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
