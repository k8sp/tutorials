# CNI简介
CNI(Container Network Interface)<sup>[1](#1)</sup>容器网络接口，是Linux容器网络配置的一组标准和库，用户需要根据这些标准和库来开发自己的容器网络插件。在[1](#1)里已经提供了一些常用的插件。CNI只专注解决容器网络连接和容器销毁时的资源释放，提供一套框架，所以CNI可以支持大量不同的网络模式，并且容易实现。

这里有两个关键的概念：

* 容器和[Linux namespace](http://man7.org/linux/man-pages/man7/namespaces.7.html)是几乎相同的概念。对于不同的容器的实现CNI是不同的，比如对于rkt和docker就是用不同的方式实现
* 网络通常指一组可以互相寻址的实体，可以是一组容器，一个服务器节点或者网络设备(比如路由器)。容器可以被动态的在这个网络中增加或删除。

CNI的目的是在容器的运行时首先创建容器的网络空间。然后确定这个容器应该属于哪个网络，需要使用哪个网络插件。网络配置使用JSON格式，方便存储在一个文件中。网络配置包括必选的```name```,```type```和plugin type详细。网络配置可以支持动态值变更，这样会存在一个可选的字段```args```包含其他信息。容器运行时顺序的执行每个插件完成对网络的配置。容器生命周期完成后，运行时以相反的顺序析构对应的网络插件。

## CNI Plugin
每个CNI plugin是通过具体的容器管理系统调用的(rkt, docker)。

CNI plugin负责完成在容器的网络namespace中插入一个网络设备(比如veth)，并完成对主机的对应配置(将veth和网桥连接)，然后为这个网络设备分配一个IP地址，并配置对应的路由(通过调用IPAM插件)

### 插件执行
CNI插件需要完成的详细步骤如下：

1. 创建网络。插件的创建网络的部分如果成功，则需要返回0，并将配置的JSON输出到stdout

	```
  {
    "cniVersion": "0.1.0",
    "ip4": {
      "ip": <ipv4-and-subnet-in-CIDR>,
      "gateway": <ipv4-of-the-gateway>,  (optional)
      "routes": <list-of-ipv4-routes>    (optional)
    },
    "ip6": {
      "ip": <ipv6-and-subnet-in-CIDR>,
      "gateway": <ipv6-of-the-gateway>,  (optional)
      "routes": <list-of-ipv6-routes>    (optional)
    },
    "dns": {
      "nameservers": <list-of-nameservers>           (optional)
      "domain": <name-of-local-domain>               (optional)
      "search": <list-of-additional-search-domains>  (optional)
      "options": <list-of-options>                   (optional)
    }
  }
	```

2. 如果发生错误，则返回非0值，并输出错误信息的JSON

	```
  {
    "cniVersion": "0.1.0",
    "code": <numeric-error-code>,
    "msg": <short-error-message>,
    "details": <long-error-message> (optional)
  }
	```

3. 一些示例配置

	```
  {
    "cniVersion": "0.1.0",
    "name": "dbnet",
    "type": "bridge",
    // type (plugin) specific
    "bridge": "cni0",
    "ipam": {
      "type": "host-local",
      // ipam specific
      "subnet": "10.1.0.0/16",
      "gateway": "10.1.0.1"
    },
    "dns": {
      "nameservers": [ "10.1.0.1" ]
    }
  }
	```

	```
	{
    "cniVersion": "0.1.0",
    "name": "pci",
    "type": "ovs",
    // type (plugin) specific
    "bridge": "ovs0",
    "vxlanID": 42,
    "ipam": {
      "type": "dhcp",
      "routes": [ { "dst": "10.3.0.0/16" }, { "dst": "10.4.0.0/16" } ]
    }
    // args may be ignored by plugins
    "args": {
      "labels" : {
          "appVersion" : "1.0"
      }
    }
  }
	```

## 在kubernetes中使用CNI
* 参考[3](#3)
* 参考：https://github.com/k8sp/kubernetes-examples/tree/master/install/cloud-config
* 使用kubernetes + Calico即会使用CNI网络插件

# 参考文献
* 1: https://github.com/containernetworking/cni
* 2: https://github.com/containernetworking/cni/blob/master/SPEC.md
* 3: http://kubernetes.io/docs/admin/network-plugins/
