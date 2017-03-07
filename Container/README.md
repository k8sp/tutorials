# 容器简介
## 容器和Docker关系
提到容器，很多人第一反应即为Docker，但实际上容器和Docker还是有一定区别的，简单来说，容器是一种轻量级的虚拟化技术，而Docker则是这种技术的一种对开发者非常友好的工具。

## 容器发展的主要里程碑
- **1979: Unix V7**

  在1979年，Unix V7 引入了一个被称为[Chroot](https://en.wikipedia.org/wiki/Chroot)的系统，并在1982年被添加到BSD中.[Chroot](https://en.wikipedia.org/wiki/Chroot)会在文件系统中创建一个新的目录，作为进程的根目录，这一特性使得不同进程拥有自己的目录权限，实现了文件系统上的隔离。
- **2000: FreeBSD Jail && Linux VServer**

  在2000年左右，出现了FressBSD Jail系统，它允许管理员将FreeBSD的系统分割成几个被称为Jails的独立系统，并且这些小系统拥有了独立的IP地址。
- **2001: Linux VServer**

  基于FreeBSD Jails，出现了[Linux VServer](https://en.wikipedia.org/wiki/Linux-VServer)，它可以在服务器上划分资源(文件系统，网络地址以及内存资源)，更加丰富了到2006年它出现在了Linux kernel的stable版本中。
- **2004~2005**

  在2004~2005年期间，出现了很多基于Linux的容器技术，例如2004年的[Solaris containers](https://en.wikipedia.org/wiki/Solaris_Containers)以及出现在2005年左右的[OpenVZ](https://en.wikipedia.org/wiki/OpenVZ)。
- **2006: Process Containers**

  Google凭借Process Contianers进入容器界，它在进程基础上对CPU，内存，磁盘IO以及网络IO资源做了限制，审计和隔离。这些特性在一年以后被加入到Linux kernel 2.6.24，并更名为**Control Groups(cgroups)** ，值得一提的是在现在的Docker版本中依然使用着cgroups技术。

- **2008: LXC**

  LXC整合了Linux Kernel中cgroups和namespace，是一种轻量级的虚拟化技术，缺点是使用过于复杂。
- **2011: Warden**

  warden支持运行在多种操作系统上，并且作为一个daemon进程运行的系统上，提供了API接口来管理系统上的容器。
- **2013: Docker**
  由于LXC的使用过于复杂，出现了Docker技术，它基于LXC封装了自己的指令体系，使其变得更为易用.Docker能够得到如此广泛认可，也得益于它可以让开发人员快速的部署，运行容器.配合Docker Hub使用，开发人员可以快速的在任何有互联网连接的地方将应用启动。

## 容器与虚拟机的对比
与虚拟机相比，容器具有更加轻量级，启动速度更快等优点，下面是容器和虚拟机的特性对比

特性|虚拟机|容器
--- | --- | ---
安全性|高|较高
隔离性|高|较高
性能|低|高
资源伸缩|重启虚拟机|重启进程
虚拟化粒度|主机级|进程级
镜像体积|大|小

## 参考文献
- [A Brief History of Containers: From 1970s chroot to Docker 2016](http://blog.aquasec.com/a-brief-history-of-containers-from-1970s-chroot-to-docker-2016)
- [Docker docs](https://docs.docker.com)
