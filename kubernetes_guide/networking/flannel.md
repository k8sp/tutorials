# Flannel Tutorial

## 简介
flanneld是一个运行在每个host上的daemon进程。它可以为所在的host维护一个网段，并且为运行在这个host上的Kubernetes pods从这个网段里分配IP地址。多个hosts上的flanneld进程可以利用etcd机群互相协调以确保各自拥有不交叠的网段，这样一个机群上的pods各自拥有互不重复的IP地址。这种构筑在一个网络（hosts网络）之上的另一个网络（flanneld维护的pods网络），被称为 [overlay network](https://en.wikipedia.org/wiki/Overlay_network)。

<img src="https://github.com/coreos/flannel/blob/master/packet-01.png" width=800 />

如上图所示，每台服务器上会启动flanneld的一个守护进程，并为本机分配一个单独的子网(图中的10.1.15.1/24)。flanneld进程启动的时候，
会从etcd中获取预先配置好的overlay network的网络配置(10.1.0.0/16，未在图中显示，但可以从图中flannel0的地址看出掩码16的网络配置)，并获取目前已经使用过的子网，然后为本机生成一个专属的子网。
子网生成完毕之后，生成/run/flannel/subnet.env文件，包含对应的子网信息。CoreOS的docker.service 使用subnet.env来配置/run/flannel_docker_opts.env。具体过程描述请参见 
https://coreos.com/flannel/docs/latest/flannel-config.html#under-the-hood 

如果配置docker.service在CoreOS中依赖flanneld.service启动，启动docker.service后docker daemon运行在这个子网，即docker生成的网桥docker0配置在本子网(--bip=10.1.15.1/24)。这样kubernetes 管理Pod的启动就会自动在
这个网段下分配IP。

## 在coreos中运行flannel

不同host上的flanneld进程通过etcd协调各自的网段，参考[这篇](https://coreos.com/etcd/docs/latest/clustering.html)文章来先完成etcd集群的部署和搭建。

完成etcd安装和启动之后，先确保etcd服务可以正确的通过http和etcdctl访问

使用下面的命令，为flanneld配置网络和模式。
* 替换```$POD_NETWORK```为实际需要配置的网段CIDR
* 替换```$ETCD_SERVER```为etcd的地址
```
curl -X PUT -d "value={\"Network\":\"$POD_NETWORK\",\"Backend\":{\"Type\":\"vxlan\"}}" "$ETCD_SERVER/v2/keys/coreos.com/network/config"
```
创建/etc/flannel/options.env文件，写入下面的配置信息：
* 替换```${ADVERTISE_IP}```为本机对外可访问的ip地址
* 替换```${ETCD_ENDPOINTS}```为etcd集群的访问地址
```
FLANNELD_IFACE=${ADVERTISE_IP}
FLANNELD_ETCD_ENDPOINTS=${ETCD_ENDPOINTS}
```
创建systemd的drop-in文件/etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf，在flannel service启动的时候拷贝配置文件到对应位置：
```
[Service]
ExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env
```
配置docker service依赖flannel启动，创建文件/etc/systemd/system/docker.service.d/40-flannel.conf
```
[Unit]
Requires=flanneld.service
After=flanneld.service
```
完成以上的配置之后，就可以使用systemctl start flanneld启动服务。如果docker此时也是未启动状态，可以直接systemctl start docker就可以
把flanneld和docker daemon同时启动。

## 配置使用不同的网络模式
flannel 有多种网络模式可以配置，
* udp模式
使用udp协议完成overlay封包。不推荐使用此模式，性能较差
* vxlan模式
直接使用linux kernel的vxlan功能封包。经过测试此模式性能损失也很大
* host-gw模式
原理和GCE模式类似，直接将发忘Pod子网的数据路由到对应的host。要求host之间有直接的L2连接。性能不错
* aws-vpc, gce模式
对应只在aws和gce环境下使用
* alloc只分配网络，不做包转发

flannel的网络模式，在初始化集群配置etcd的时候就需要设置好，参考上面的步骤。
