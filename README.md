<<<<<<< HEAD
# tutorials
=======
# Kubernetes实战教程

* 一个运行Paddle Job的例子
* 一个现实的例子
    * 处理任务依赖
    * AI计算的全生命周期
    * 为什么实现AI的目标需要Kubernetes
        * 通用计算集群的重要性(介绍不同业务集群相互独立，造成的利用率低下)
* 容器简介
   * 资源隔离的必要性
       * 物理隔离
       * 多账户
       * 虚拟机
       * 容器／沙盒
   * 容器和虚拟机的对比
   * 多个实现：warden, rkt, lxc, docker, sandbox
   * 功能
       * 运行环境隔离(kernel namespaces)
       * 资源配额Control groups
       * Layer FS
       * 应用打包语言Dockerfile
       * 跨平台（Mac, Linux, Windows）
       * 网络映射(NAT)
* 容器集群化
   * 现状和问题
       * 业界计算集群资源利用率普遍很低
       * 在线集群和离线任务集群 独立部署
   * 现有集群资源管理软件的横向对比（Mesos、Yarn等）
   * Kubernetes带来的特性
       * 同时调度在线业务和离线业务
       * 支持Stateless和Stateful两种分布式应用部署
       * 经过Google检验的容器调度和管理（health, recover, ）
           * 在线更新Rolling update
           * 扩容缩容
           * 故障恢复
           * 资源调度机制
           * label调度
       * Kubernetes网络模型
           * Flannel原理(docker0的作用，UDP、host-gw的区别)
           * Service机制(cluster-ip、node-port)
           * 如何处理集群外部的访问(7层代理-ingress，4层代理-loadbalancer)
       * kubernetes的存储模型
           * Volume的机制
       * Kubernetes的监控架构
           * 基于heapster+influxdb+grafana的解决方案
       * Kubernetes的统一日志处理
           * 基于Elasticsearch+Fluentd+Kibana(EFK)的解决方案
* 存储集群
   * 块设备和对象存储, S3 API成为行业标准
   * 数据容灾
   * 存储服务容灾
   * SSD和多级存储
* 作业管理
   * 可视化作业管理（锦上添花，欲善其事，先利其器）
   * 处理相互依赖关系的作业调度（类似于ETL任务调度）
* 应用场景
   * 行业AI服务一体机
       * 人脸识别
       * 推荐系统
       * 舆情系统
   * AI开发平台
      * ServerLess服务
      * 大数据和AI
>>>>>>> 9b4d60bfd4a264633cc3edaaa8b26df9827e3a83
