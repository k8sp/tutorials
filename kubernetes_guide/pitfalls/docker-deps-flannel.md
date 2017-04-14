# 坑：Docker Doesn't Work with CoreOS Any More?!

## 问题

今天碰到一个坑——我打开很久没用的一台安装了CoreOS的物理机器，用Docker运行Torch，但是`docker run`命令卡死在那儿不动了。我又试了试，`docker version`也是卡死的。而一个月前我还用过这台机器做同样的事情。这一个月我不在家，对这台机器什么也没做！

我试着手动升级了我的CoreOS操作系统，但是问题依旧！

## 原因

问题在于docker.service没有启动起来，所以docker命令没有反应。docker.service是因为依赖的flanneld失败而没有启动的。而flanneld是因为etcd里没有它需要的`/coreos.com/network/config`所以失败的。

深究原因，899版本的CoreOS里，docker.service不依赖flanneld，所以原来docker.service可以没有问题地启动。

而flanneld 和docker.service都是以Docker images的形式发布的（而不是CoreOS的一部分），所以今天使用的时候用到了新版本的flanneld，它需要通过etcd配置。可是之前没有配置过，所以失败了。

flanneld的失败本不应该导致docker.service的失败。但是不知什么原因，依赖关系也被更新了，docker.service依赖flanneld了，所以docker失效了。

手工升级CoreOS后，在1010版本里，docker.service就是依赖flanneld的。

## 解决

文山和总理建议我手工执行

```
etcdctl set /coreos.com/network/config '{ "Network": "10.1.0.0/16" }'
```

往这台机器的etcd里写入了flanneld需要的子网配置，随后

```
sudo systemctl start docker
```

就重新尝试启动docker及其依赖的flanneld。因为docker和flanneld需要从Docker服务器下载images，所以需要一段时间。此后就可以用docker了。

## 探索

当docker不工作的时候，家盟建议我检查了docker.service的状态：

```
core@localhost ~ $ sudo systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib64/systemd/system/docker.service; enabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/docker.service.d
           └─40-flannel.conf
   Active: inactive (dead)
     Docs: http://docs.docker.com

Jun 24 01:04:46 localhost systemd[1]: Dependency failed for Docker Application Container Engine.
Jun 24 01:04:46 localhost systemd[1]: docker.service: Job docker.service/start failed with result 'dependency'.
```

显示失败了。而且原因是`Dependency failed for Docker Application Container Engine`。

因为同事们之前碰到过类似问题，所以建议我看看 docker 依赖的 flanneld 的状态：

```
core@localhost ~ $ systemctl status flanneld
● flanneld.service - Network fabric for containers
   Loaded: loaded (/usr/lib64/systemd/system/flanneld.service; disabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/flanneld.service.d
           └─40-ExecStartPre-symlink.conf
	   Active: activating (start) since Fri 2016-06-24 00:47:13 UTC; 1min 11s ago
```

显示在activating（在挣扎着启动，但是用了很长时间也没能启动）。家盟进一步建议看看flanneld的log：

```
core@localhost ~ $ journalctl -exl -u flanneld.service
Jun 24 00:53:35 localhost sdnotify-proxy[1481]: I0624 00:53:35.558114 00001 main.go:275] Installing signal handlers
Jun 24 00:53:35 localhost sdnotify-proxy[1481]: I0624 00:53:35.558301 00001 main.go:188] Using 192.168.1.134 as external interface
Jun 24 00:53:35 localhost sdnotify-proxy[1481]: I0624 00:53:35.558316 00001 main.go:189] Using 192.168.1.134 as external endpoint
Jun 24 00:53:35 localhost sdnotify-proxy[1481]: E0624 00:53:35.558923 00001 network.go:53] Failed to retrieve network config: 100: Key not found (/coreos.com/network) [17]
Jun 24 00:53:36 localhost sdnotify-proxy[1481]: E0624 00:53:36.559596 00001 network.go:53] Failed to retrieve network config: 100: Key not found (/coreos.com/network) [17]
Jun 24 00:53:37 localhost sdnotify-proxy[1481]: E0624 00:53:37.560144 00001 network.go:53] Failed to retrieve network config: 100: Key not found (/coreos.com/network) [17]
Jun 24 00:53:38 localhost sdnotify-proxy[1481]: E0624 00:53:38.560671 00001 network.go:53] Failed to retrieve network config: 100: Key not found (/coreos.com/network) [17]
```

Google了一下，根据搜索结果 https://github.com/coreos/flannel/issues/345 的描述，貌似是etcd没有启动起来。而且看etcd状态

```
core@localhost ~ $ systemctl status etcd
● etcd.service - etcd
   Loaded: loaded (/usr/lib64/systemd/system/etcd.service; static; vendor preset: disabled)
   Active: inactive (dead)
```

确实是没启动起来。

但是这其实是一个陷阱——CoreOS用的是etcd2，而不是etcd。`systemctl status etcd2` 显示 `active (running)`。

根据上面log里反复出现的信息

```
Key not found (/coreos.com/network) [17]
```

猜想这里的"key"指的是etcd里的key。用etcdctl检查，确实没有这个key:

```
core@localhost ~ $ etcdctl ls /coreos.com
/coreos.com/updateengine
```

同时，我们注意到因为flanneld没有启动起来，所以`ifconfig`看不到`flannel0`设备。`flannel0`是flanneld创建的虚拟网桥，详细情况请看[这里](https://github.com/coreos/flannel)。而且因为docker.service依赖flanneld，所以docker.service也没有启动起来，因此`ifconfig`也看不到本应存在的`docker0`虚拟网桥。

在最新的flanneld的配置[文档](https://coreos.com/flannel/docs/latest/flannel-config.html)里，提到flanneld的配置信息要在etcd里配置。照做之后，解决问题。

为了验证 899 和 1010 里，systemd units之间的依赖关系发生了变化，我在一台运行899版本的虚拟机里，用如下命令

```
systemctl list-dependencies docker
```

检查了依赖docker.service的其他units：左边是899的，右边是1010的。可以看出，在899里docker不依赖flanneld，但是在1010里，docker依赖flanneld。

<img width=600 src=unit-deps-899-vs-1010.png />
