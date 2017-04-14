# kubernetes网络性能
介绍kubernetes常见的网络模型和配置方法以及不同网络模型的性能评测

## 环境准备
* OS: CoreOS alpha
* kubernetes master: 在一台虚拟机上部署kubernetes master相关组件。master本身不作为性能测试机，只作为集群的管理和协调者(172.24.3.150)。
* kubernetes nodes: 在两台物理机上部署kubernetes worker节点的相关组件(两台物理机分别为172.24.2.207, 172.24.2.208)。
* flannel 版本： 0.5.5
* calico 版本: 1.3.1
* 物理机配置：
```
24 core Intel(R) Xeon(R) CPU E5-2620 v2 @ 2.10GHz
64G memory
Intel Corporation I350 Gigabit Network Connection 千兆网卡（4口，评测中只使用第一个网口）
```
## 搭建kubernetes相关组件，并配置不同的网络模式
使用下面这个链接的cloud-config完成master和worker的配置：https://github.com/typhoonzero/kubernetes_binaries/tree/master/cloud-config
部署方式参考[这个](https://github.com/typhoonzero/kubernetes_binaries/blob/master/README.md)链接

## 为这两个物理节点增加label:
```
kubectl label no 172.24.2.207 workern=1
kubectl label no 172.24.2.208 workern=2
```

## 性能评测指标：

1. ping延迟: 用ping测试hosts之间和pods之间的延迟
1. 带宽测试: 用iperf3测试hosts之间和pods之间的带宽
1. HTTP性能测试: 部署单进程nginx server并使用apache benchmark(ab)测试

## 物理机性能评测

### ping延迟
登录到172.24.2.207，运行```ping 172.24.2.208```测试延迟：
```
# ping 172.24.2.208
PING 172.24.2.208 (172.24.2.208) 56(84) bytes of data.
64 bytes from 172.24.2.208: icmp_seq=1 ttl=64 time=0.151 ms
64 bytes from 172.24.2.208: icmp_seq=2 ttl=64 time=0.121 ms
64 bytes from 172.24.2.208: icmp_seq=3 ttl=64 time=0.138 ms
64 bytes from 172.24.2.208: icmp_seq=4 ttl=64 time=0.147 ms
64 bytes from 172.24.2.208: icmp_seq=5 ttl=64 time=0.145 ms
64 bytes from 172.24.2.208: icmp_seq=6 ttl=64 time=0.116 ms
64 bytes from 172.24.2.208: icmp_seq=7 ttl=64 time=0.154 ms
```
平均值为： 0.1389 ms

*注：可以通过下面的脚本例子计算ping延迟的平均值，注意split的列可能根据ping的输出不同而不同，对于上面的例子split列应该是7*
```
core@core-03 ~ $ ping localhost | head -n 20 | gawk '/time/ {split($8, ss, "="); sum+=ss[2]; count+=1;} END{print sum/count "ms";}'
0.0275556ms
```

### iperf3带宽
在172.24.2.207和172.24.2.208的CoreOS使用[toolbox](https://coreos.com/os/docs/latest/install-debugging-tools.html)命令后，输入```yum install -y iperf3```安装iperf3。然后在172.24.2.207上启动iperf3 server: ```iperf3 -s```，在172.24.2.208启动客户端，执行下面命令:
```
# iperf3 -c 172.24.2.207
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.10 GBytes   942 Mbits/sec    0             sender
[  4]   0.00-10.00  sec  1.10 GBytes   941 Mbits/sec                  receiver
```

### nginx benchmark
先在172.24.2.207上，执行```docker run --net=host nginx```启动一个单进程的nginx服务，然后在172.24.2.208上执行```toolbox```进入CoreOS工具箱。使用下面命令预先安装apache benchmark(ab命令)```yum install -y httpd-tools```，然后使用```ab -n 90000 -c 50 http://172.24.2.207/```开始压测，结果如下：
```
Document Path:          /
Document Length:        612 bytes

Concurrency Level:      50
Time taken for tests:   6.808 seconds
Complete requests:      90000
Failed requests:        0
Total transferred:      76050000 bytes
HTML transferred:       55080000 bytes
Requests per second:    13220.57 [#/sec] (mean)
Time per request:       3.782 [ms] (mean)
Time per request:       0.076 [ms] (mean, across all concurrent requests)
Transfer rate:          10909.55 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.8      0       5
Processing:     1    3   1.7      3      14
Waiting:        0    3   1.7      3      14
Total:          1    4   1.7      3      15
WARNING: The median and mean for the initial connection time are not within a normal deviation
        These results are probably not that reliable.

Percentage of the requests served within a certain time (ms)
  50%      3
  66%      4
  75%      4
  80%      5
  90%      5
  95%      6
  98%      9
  99%     14
 100%     15 (longest request)
```

## flannel host-gw模式评测

### ping延迟
在pod之间的ping延迟，通过```kubectl create -f curl_pod.yaml```启动一个busybox的pod，然后查看这个pod所在的host的地址：```kubectl describe po busybox```，在和busybox pod不同的host上启动一个pod，比如：```kubectl create -f ./perf_pod_2.yaml```，并获得这个pod的ip，如10.1.25.2)，然后执行下面的命令获得ping延迟:
```
kubectl exec -it busybox -- ping 10.1.25.2
PING 10.1.25.2 (10.1.25.2): 56 data bytes
64 bytes from 10.1.25.2: seq=0 ttl=62 time=0.386 ms
64 bytes from 10.1.25.2: seq=1 ttl=62 time=0.197 ms
64 bytes from 10.1.25.2: seq=2 ttl=62 time=0.299 ms
64 bytes from 10.1.25.2: seq=3 ttl=62 time=0.318 ms
64 bytes from 10.1.25.2: seq=4 ttl=62 time=0.320 ms
64 bytes from 10.1.25.2: seq=5 ttl=62 time=0.258 ms
64 bytes from 10.1.25.2: seq=6 ttl=62 time=0.261 ms
64 bytes from 10.1.25.2: seq=7 ttl=62 time=0.368 ms
64 bytes from 10.1.25.2: seq=8 ttl=62 time=0.267 ms
```
平均延迟： 0.297111ms

### iperf3带宽
pod之间的iperf3带宽:

使用下面命令启动两个pod，iperfbox1, iperfbox2，使用nodeSelector启动不同的host上。可以在本目录下找到iperfbox的yaml文件(./perf_pod_1.yaml)和(./perf_pod_2.yaml)
```
kubectl create -f ./perf_pod_1.yaml
kubectl create -f ./perf_pod_2.yaml
```
然后iperfbox1作为server，执行```kubectl exec -it iperfbox1 -- iperf3 -s```。然后从iperfbox2访问iperfbox1的IP来测试带宽，使用```kubectl describe po iperfbox1```iperfbox1的IP如10.1.66.5：

```
kubectl exec -it iperfbox2 -- iperf3 -c 10.1.66.5
...
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.10 GBytes   944 Mbits/sec  134             sender
[  4]   0.00-10.00  sec  1.10 GBytes   941 Mbits/sec                  receiver
```

### nginx benchmark
pod内的nginx性能：

用RC创建Nginx pod，并且封装成一个NodePort类型的service:
```
kubectl create -f nginx-replication-controller.yaml
kubectl create -f nginx-service-nodeport.yaml
```
使用nodeport访问和clusterIP访问```ab -n 90000 -c 50 http://172.24.2.207:30001/```，性能相近。：
```
Server Software:        nginx/1.11.1
Server Hostname:        172.24.2.207
Server Port:            30001

Document Path:          /
Document Length:        612 bytes

Concurrency Level:      50
Time taken for tests:   8.322 seconds
Complete requests:      90000
Failed requests:        0
Total transferred:      76050000 bytes
HTML transferred:       55080000 bytes
Requests per second:    10815.20 [#/sec] (mean)
Time per request:       4.623 [ms] (mean)
Time per request:       0.092 [ms] (mean, across all concurrent requests)
Transfer rate:          8924.65 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   1.4      1      10
Processing:     1    3   1.8      3      22
Waiting:        1    3   1.9      3      22
Total:          2    5   2.1      4      23

Percentage of the requests served within a certain time (ms)
  50%      4
  66%      4
  75%      5
  80%      6
  90%      7
  95%      7
  98%     10
  99%     13
 100%     23 (longest request)
```

## 使用flannel vxlan模式评测：
**物理机之间的ping延迟，iperf3带宽，nginx性能参考上面数据**
### pod之间的ping延迟：
操作步骤同上
```
kubectl exec -it busybox -- ping 10.1.87.2
PING 10.1.87.2 (10.1.87.2): 56 data bytes
64 bytes from 10.1.87.2: seq=0 ttl=62 time=0.515 ms
64 bytes from 10.1.87.2: seq=1 ttl=62 time=0.271 ms
64 bytes from 10.1.87.2: seq=2 ttl=62 time=0.308 ms
64 bytes from 10.1.87.2: seq=3 ttl=62 time=0.294 ms
64 bytes from 10.1.87.2: seq=4 ttl=62 time=0.838 ms
64 bytes from 10.1.87.2: seq=5 ttl=62 time=0.374 ms
64 bytes from 10.1.87.2: seq=6 ttl=62 time=0.239 ms
64 bytes from 10.1.87.2: seq=7 ttl=62 time=0.260 ms
64 bytes from 10.1.87.2: seq=8 ttl=62 time=0.240 ms
64 bytes from 10.1.87.2: seq=9 ttl=62 time=0.244 ms
64 bytes from 10.1.87.2: seq=10 ttl=62 time=0.247 ms
64 bytes from 10.1.87.2: seq=11 ttl=62 time=0.380 ms
64 bytes from 10.1.87.2: seq=12 ttl=62 time=0.284 ms
64 bytes from 10.1.87.2: seq=13 ttl=62 time=0.302 ms
64 bytes from 10.1.87.2: seq=14 ttl=62 time=0.278 ms
64 bytes from 10.1.87.2: seq=15 ttl=62 time=0.345 ms
64 bytes from 10.1.87.2: seq=16 ttl=62 time=0.330 ms
```
平均延迟：0.338176ms

### pod之间的带宽
操作步骤同上
```
kubectl exec -it iperfbox1 -- iperf3 -c 10.1.87.2
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.06 GBytes   912 Mbits/sec  192             sender
[  4]   0.00-10.00  sec  1.06 GBytes   909 Mbits/sec                  receiver
```
### nginx性能
操作步骤同上
```
Server Software:        nginx/1.11.1
Server Hostname:        172.24.2.207
Server Port:            30001

Document Path:          /
Document Length:        612 bytes

Concurrency Level:      50
Time taken for tests:   8.945 seconds
Complete requests:      90000
Failed requests:        0
Total transferred:      76050000 bytes
HTML transferred:       55080000 bytes
Requests per second:    10061.15 [#/sec] (mean)
Time per request:       4.970 [ms] (mean)
Time per request:       0.099 [ms] (mean, across all concurrent requests)
Transfer rate:          8302.41 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    2   1.4      2       6
Processing:     1    3   1.4      3      12
Waiting:        1    3   1.3      2      10
Total:          2    5   1.5      5      14

Percentage of the requests served within a certain time (ms)
  50%      5
  66%      5
  75%      6
  80%      6
  90%      7
  95%      7
  98%     10
  99%     10
 100%     14 (longest request)
```

## 使用kubernetes + Calico测试网络性能
* 根据http://kubernetes.io/docs/getting-started-guides/coreos/bare_metal_calico/ 完成1个master，2个host的集群部署

### ping延迟
(192.168.0.64为在不同host启动的pod的IP地址)
```
kubectl exec -it busybox -- ping 192.168.0.64
PING 192.168.0.64 (192.168.0.64): 56 data bytes
64 bytes from 192.168.0.64: seq=0 ttl=62 time=0.377 ms
64 bytes from 192.168.0.64: seq=1 ttl=62 time=0.241 ms
64 bytes from 192.168.0.64: seq=2 ttl=62 time=0.210 ms
64 bytes from 192.168.0.64: seq=3 ttl=62 time=0.236 ms
64 bytes from 192.168.0.64: seq=4 ttl=62 time=0.236 ms
64 bytes from 192.168.0.64: seq=5 ttl=62 time=0.232 ms
64 bytes from 192.168.0.64: seq=6 ttl=62 time=0.285 ms
64 bytes from 192.168.0.64: seq=7 ttl=62 time=0.266 ms
64 bytes from 192.168.0.64: seq=8 ttl=62 time=0.358 ms
64 bytes from 192.168.0.64: seq=9 ttl=62 time=0.223 ms
64 bytes from 192.168.0.64: seq=10 ttl=62 time=0.261 ms
64 bytes from 192.168.0.64: seq=11 ttl=62 time=0.286 ms
64 bytes from 192.168.0.64: seq=12 ttl=62 time=0.237 ms
64 bytes from 192.168.0.64: seq=13 ttl=62 time=0.288 ms
64 bytes from 192.168.0.64: seq=14 ttl=62 time=0.249 ms
64 bytes from 192.168.0.64: seq=15 ttl=62 time=0.188 ms
64 bytes from 192.168.0.64: seq=16 ttl=62 time=0.243 ms
64 bytes from 192.168.0.64: seq=17 ttl=62 time=0.254 ms
64 bytes from 192.168.0.64: seq=18 ttl=62 time=0.279 ms
64 bytes from 192.168.0.64: seq=19 ttl=62 time=0.217 ms
64 bytes from 192.168.0.64: seq=20 ttl=62 time=0.216 ms
64 bytes from 192.168.0.64: seq=21 ttl=62 time=0.205 ms
64 bytes from 192.168.0.64: seq=22 ttl=62 time=0.251 ms
64 bytes from 192.168.0.64: seq=23 ttl=62 time=0.200 ms
```
平均延迟：0.251583ms
### iperf3带宽
评测方法同上
```
kubectl exec -it iperfbox1 -- iperf3 -c 192.168.0.64
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.10 GBytes   945 Mbits/sec  137             sender
[  4]   0.00-10.00  sec  1.10 GBytes   941 Mbits/sec                  receiver
```
### nginx benchmark
评测方法同上
```
Server Software:        nginx/1.11.1
Server Hostname:        172.24.2.207
Server Port:            30001

Document Path:          /
Document Length:        612 bytes

Concurrency Level:      50
Time taken for tests:   8.655 seconds
Complete requests:      90000
Failed requests:        0
Total transferred:      76050000 bytes
HTML transferred:       55080000 bytes
Requests per second:    10398.93 [#/sec] (mean)
Time per request:       4.808 [ms] (mean)
Time per request:       0.096 [ms] (mean, across all concurrent requests)
Transfer rate:          8581.14 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.9      0       7
Processing:     1    4   1.9      3      19
Waiting:        1    4   2.0      3      19
Total:          2    5   1.7      4      19
WARNING: The median and mean for the initial connection time are not within a normal deviation
        These results are probably not that reliable.

Percentage of the requests served within a certain time (ms)
  50%      4
  66%      5
  75%      5
  80%      6
  90%      8
  95%      8
  98%      8
  99%      9
 100%     19 (longest request)
```

# 其他网络方式的尝试
## 使用类似GCE方式手动配置kubernetes网络
以下部分为手动配置kubernetes网络，形成类似GCE方式的网络，可以获得较高的性能。但由于目前只能实现手动配置，在实际生产环境使用有待进一步研究。参考链接：http://kubernetes.io/docs/admin/networking/#google-compute-engine-gce

1. 根据https://coreos.com/kubernetes/docs/latest/getting-started.html 这个教程启动一个kubernetes master节点(无flannel, calico policy等)。
1. 使用下面的方法配置/etc/systemd/system/kubelet.service如下，注意增加--configure-cbr0=true参数(此参数在后续版本中会被network-plugin功能替换)：
  ```
  [Service]
  ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests

  Environment=KUBELET_VERSION=v1.2.4_coreos.1

  ExecStart=/usr/lib/coreos/kubelet-wrapper \
    --pod_infra_container_image=typhoon1986/pause:2.0 \
    --api-servers=http://172.24.3.150:8080 \
    --network-plugin-dir=/etc/kubernetes/cni/net.d \
    --network-plugin=${NETWORK_PLUGIN} \
    --register-schedulable=false \
    --allow-privileged=true \
    --config=/etc/kubernetes/manifests \
    --hostname-override=<YOUR_IP> \
    --cluster-dns=10.0.0.10 \
    --cluster-domain=cluster.local \
    --configure-cbr0=true
  Restart=always
  RestartSec=10
  [Install]
  WantedBy=multi-user.target
  ```
1. 重启docker daemon，增加以下参数```DOCKER_OPTS="--bridge=cbr0 --iptables=false --ip-masq=false"```，可以使用systemd drop-in文件，配置：
  ```
  [Service]
  Environment=DOCKER_OPTS="--bridge=cbr0 --iptables=false --ip-masq=false"
  ```
1. 使用下面的配置文件(node_1.yaml)给当前的节点配置对应的CIDR(比如：10.1.40.0/24)，执行```kubectl create -f node_1.yaml```:
  ```
  {
    "kind": "Node",
    "apiVersion": "v1",
    "metadata": {
      "name": "<YOUR_IP>",
      "labels": {
        "name": "my-first-k8s-node-1"
      }
    },
    "spec": {
      "podCIDR": "10.1.40.0/24"
    }
  }
  ```
1. 此时worker节点的kubelet进程会根据设置的CIDR创建cbr0的网桥，如果没有创建成功可以尝试重启kubelet服务。
1. 因为这个时候host和cbr0之间是相互无法感知的，需要增加一条NAT配置，将Pod CIDR的网络可以转发到实际的物理网络(假设设置的Pod的子网都在10.1.0.0/16这个子网下)。如下：
  ```
  iptables -t nat -A POSTROUTING ! -d 10.1.0.0/16 -o eth0 -j MASQUERADE
  ```
1. 启动多个worker，并在每个worker上增加路由表，使发向这个host上的Pod CIDR的包都路由到对应host的物理机的IP地址，比如：
  ```
  10.1.40.0/24 via 172.24.2.207 dev eno1
  ```
1. 此时即可完成对网络的配置，Pod之间、Pod和host之间可以互相访问。

## 二层网络方式组建kubernetes集群
1. 根据https://coreos.com/kubernetes/docs/latest/getting-started.html 这个教程启动一个kubernetes master节点(无flannel, calico policy等)，master节点不需要配置L2网络相关功能，master组件均已```docker run --net=host ...```方式启动，worker和client可以直接连接
1. 在交换机预先为每个worker配置好需要使用的网段，这里分配的是172.24.102.0/24和172.24.103.0/24，使得在这个网段下分配的IP地址可以直接被交换机转发，在我的测试环境下，转发的网关为：172.24.1.12
1. 将每个worker的默认网卡设备的默认IP地址改成上面分配好的网段的第一个ip：172.24.102.1，172.24.103.1，并修改默认路由也使用这个IP
1. 根据[这里](http://blog.oddbit.com/2014/08/11/four-ways-to-connect-a-docker/)Linux Bridge部分提到的方法，在每个worker上配置一个br-eno1的网桥，并将机器的默认IP绑定到这个网桥上
1. 配置docker 的drop-in文件，使docker在启动时使用这个网桥和对应的子网:
  ```
  [Service]
  Environment="DOCKER_OPTS=--bridge=br-eno1 --iptables=false --ip-masq=false --fixed-cidr=172.24.103.0/24 --default-gateway=172.24.1.12"
  ```
  然后重启docker服务:
  ```
  systemctl daemon-reload
  systemctl restart docker
  ```
1. 根据[这里](https://github.com/k8sp/kubernetes-examples/tree/master/install/cloud-config)的方法启动kubernetes worker节点：```systemctl start kubelet```
1. 此时启动的pod将会分配在配置好的L2网络下的IP地址并被自动路由，但由于之前docker daemon的启动默认会开启iptables并创建一些规则，iptables和conntrack相关的内核模块会自动被加载，在iptables存在很简单的规则时，也会导致nginx的性能降低约10%，尝试使用下面的方法卸载worker节点的iptables和conntrack内核模块：
  先创建一个脚本：
  ```
  #!/bin/bash

  #/sbin/modprobe --version 2>&1 | grep -q module-init-tools \
  #    && NEW_MODUTILS=1 \
  #    || NEW_MODUTILS=0

  NEW_MODUTILS=1
  IPTABLES=iptables
  IPV＝ip
  PROC_IPTABLES_NAMES=/proc/net/${IPV}_tables_names
  NF_TABLES=$(cat "$PROC_IPTABLES_NAMES" 2>/dev/null)

  echo $PROC_IPTABLES_NAMES
  echo $NF_TABLES

  rmmod_r() {
      # Unload module with all referring modules.
      # At first all referring modules will be unloaded, then the module itself.
      local mod=$1
      local ret=0
      local ref=

      # Get referring modules.
      # New modutils have another output format.
      [ $NEW_MODUTILS = 1 ] \
          && ref=$(lsmod | awk "/^${mod}/ { print \$4; }" | tr ',' ' ') \
          || ref=$(lsmod | grep ^${mod} | cut -d "[" -s -f 2 | cut -d "]" -s -f 1)

      # recursive call for all referring modules
      for i in $ref; do
          rmmod_r $i
          let ret+=$?;
      done

      # Unload module.
      # The extra test is for 2.6: The module might have autocleaned,
      # after all referring modules are unloaded.
      if grep -q "^${mod}" /proc/modules ; then
          modprobe -r $mod > /dev/null 2>&1
          res=$?
          [ $res -eq 0 ] || echo -n " $mod"
          let ret+=$res;
      fi

      return $ret
  }

  flush_n_delete() {
      # Flush firewall rules and delete chains.
      [ ! -e "$PROC_IPTABLES_NAMES" ] && return 0

      # Check if firewall is configured (has tables)
      [ -z "$NF_TABLES" ] && return 1

      echo -n $"${IPTABLES}: Flushing firewall rules: "
      ret=0
      # For all tables
      for i in $NF_TABLES; do
          # Flush firewall rules.
      $IPTABLES -t $i -F;
      let ret+=$?;

          # Delete firewall chains.
      $IPTABLES -t $i -X;
      let ret+=$?;

      # Set counter to zero.
      $IPTABLES -t $i -Z;
      let ret+=$?;
      done

      #[ $ret -eq 0 ] && success || failure
      echo
      return $ret
  }

  flush_n_delete

  rmmod_r iptable_nat
  rmmod_r nf_nat_ipv4
  rmmod_r iptable_filter
  rmmod_r ip_tables
  rmmod_r x_tables
  rmmod_r nf_nat
  rmmod_r nf_conntrack
  ```
  递归卸载iptables相关模块，然后增加一个docker的drop-in文件在启动docker之后卸载模块：
  ```
  # vim /etc/systemd/system/docker.service.d/modprobe.conf
  [Service]
  ExecStartPost=-/bin/systemctl restart iptables
  ExecStartPost=-/sbin/modprobe -r nf_nat_ipv4 nf_nat nf_conntrack_ipv4 nf_conntrack
  ```
  重启docker服务
  ```
  # systemctl daemon-reload
  # systemctl restart docker
  # lsmod | grep conntrack
  ```
1. 此方式仍然会导致其他问题，参考：https://github.com/k8sp/issues/issues/27，但可以达到100%的物理机性能。

# 结论
|网络类型|延迟|带宽|nginx(QPS/延迟)|
| --- | --- | --- | --- |
|物理|0.1389 ms|942Mb/s|13220.57/3.782|
|flannel host-gw|0.297111ms|944Mb/s|10815.20/4.623|
|flannel vxlan|0.338176ms|912Mb/s|10061.15/4.970|
|Calico|0.251583ms|945Mb/s|10398.93/4.808|
|L2模式|0.15 ms|942Mb/s|14864.62/3.364|

# TODO
* Calico网络模式的介绍
