# CentOS 5 编译 GLFW3 + OpenGL2 完整指南

这样可以让centos5 也能用imgui了

copyright 2026 fgfxf

> **重要提示：请严格按照本文档顺序编译源码，否则会因为依赖缺失导致编译失败。**

---

这个项目受到qihoo 360的赞助

## 目录

- [1. 环境准备](#1-环境准备)
- [2. XCB库](#2-xcb库)
- [3. X11依赖](#3-x11依赖)
- [4. mesa库依赖](#4-mesa库依赖)
- [5. X11扩展库](#5-x11扩展库)
- [6. 编译 Mesa (OpenGL)](#6-编译-mesa-opengl)
- [7. 编译 GLFW3](#7-编译-glfw3)
- [8. 常见问题修复](#8-常见问题修复)
- [9. 制作 GCC sysroot](#9-制作-gcc-sysroot)
- [附录：依赖关系速查表](#附录依赖关系速查表)

---

## 1. 环境准备

## 1.1 系统环境

- 可以联网的centos5（可以是docker）
- 内含红帽公司的devtoolset-2 兼容编译器（gcc-4.8.x编译器）
centos5的devtoolset-2仓库地址：https://linuxsoft.cern.ch/cern/devtoolset/
devtoolset-2能让gcc-4.8.x编译器编译产物兼容centos 5 （GLIBC-2.5）

### 1.2 安装 pthread-stubs（解决 Mesa 编译时缺少 pthread stub 的问题）

```bash
cat > /usr/local/lib/pkgconfig/pthread-stubs.pc <<EOF
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: pthread-stubs
Description: Dummy pthread-stubs
Version: 0.3
Cflags: -I${includedir}
Libs: -lpthread
EOF
```

### 1.3 pkgconfig通用验证
所有的组件，我们都安装到了/usr/local
```
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:$PKG_CONFIG_PATH
pkg-config --modversion pthread-stubs
```
应该会显示：
```
0.3
```
> 其他组件同理。

> **如果没有特殊提醒，正常情况下每个组件都会编译动态库和静态库。**

> **如果make时没有-j，则表示make命令可能就是生成几个头文件，没有编译过程。**

### 1.4 升级autoconf
除了libXtrans(x11的依赖)用到了autoconf之外，其他都是configure脚本。
```bash
wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz
tar xzf autoconf-2.71.tar.gz
cd autoconf-2.71

./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
/usr/local/bin/autoconf --version
# 可以输出 2.71 或更高
```
### 1.5 python2.5以上版本
```bash
wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
tar xzf Python-2.7.18.tgz
cd Python-2.7.18
./configure --prefix=/usr/local/python2.7 --enable-optimizations
make -j$(nproc)
sudo make install
export PATH=/usr/local/python2.7/bin:$PATH
export PYTHONPATH=/usr/local/python2.7/lib/python2.7/site-packages:$PYTHONPATH
python2.7 --version
``` 


---

## 2. XCB库
是x11和mesa的依赖库
### 2.1 xcb协议（xcb-proto）
```bash
wget https://www.x.org/releases/individual/proto/xcb-proto-1.14.1.tar.gz
tar -xf xcb-proto-1.14.1.tar.gz
cd xcb-proto-1.14.1
./configure --prefix=/usr/local
make
make install
cd ..
```
### 2.2 修复xcb-proto的bug
（也可以用别的版本，可能修好了bug）
`Variable 'pc_sysrootdir' not defined in '/usr/local/lib/pkgconfig/xcb-proto.pc'`
缺少了pc_sysrootdir，需要手动添加：
```bash
cat > /usr/local/lib/pkgconfig/xcb-proto.pc <<EOF
prefix=/usr/local
exec_prefix=${prefix}
datarootdir=${prefix}/share
datadir=${datarootdir}
libdir=${exec_prefix}/lib
xcbincludedir=/usr/local/share/xcb
pythondir=${prefix}/lib/python2.7/site-packages

Name: XCB Proto
Description: X protocol descriptions for XCB
Version: 1.14.1
EOF
```
### 2.3 xproto 依赖
```bash
wget https://www.x.org/releases/individual/proto/xproto-7.0.31.tar.gz
tar xvf xproto-7.0.31.tar.gz
cd xproto-7.0.31
./configure --prefix=/usr/local/
make
make install
cd ..
```
### 2.4 xau 依赖

```bash
wget https://www.x.org/releases/individual/lib/libXau-1.0.9.tar.gz
tar xzf libXau-1.0.9.tar.gz
cd libXau-1.0.9
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
cd ..
```
### 2.5 libxcb核心库

```bash
wget https://www.x.org/releases/individual/lib/libxcb-1.14.tar.gz
tar -xf libxcb-1.14.tar.gz
cd libxcb-1.14
./configure --prefix=/usr/local
make
make install
cd ..
```
如果出现错误
1:看看/usr/local/lib/pkgconfig/xcb-proto.pc的路径是否正确。
pkg-config --modversion  xcb
2:
    from xcbgen.state import Module
ImportError: No module named xcbgen.state
设置环境变量:
find / | grep  xcbgen.state
看看xcbgen的路径，然后
export PYTHONPATH=/usr/local/lib/python2.7/site-packages:$PYTHONPATH

---
## 3. X11依赖

No package 'xextproto' found
No package 'xtrans' found
No package 'kbproto' found
No package 'inputproto' found
依赖xcb，已经在上一步解决。

### 3.1 xextproto

```bash
wget https://www.x.org/releases/individual/proto/xextproto-7.2.1.tar.gz
tar -xvf xextproto-7.2.1.tar.gz
cd  xextproto-7.2.1
./configure --prefix=/usr/local/
make
make install
cd ..
```

### 3.2 xorg基础宏util-macros (xorg-macros)
```bash
wget https://www.x.org/releases/individual/util/util-macros-1.19.3.tar.gz
tar -xf util-macros-1.19.3.tar.gz
cd util-macros-1.19.3
./configure --prefix=/usr/local/
make install
cd ..
```

### 3.3 kbproto

```bash
wget https://www.x.org/releases/individual/proto/kbproto-1.0.7.tar.gz
tar xzf kbproto-1.0.7.tar.gz
cd kbproto-1.0.7
./configure --prefix=/usr/local
make -j $(nproc)
make install
cd ..
```

### 3.4 inputproto
```bash
# 下载 XInput2 proto headers
wget https://www.x.org/releases/individual/proto/inputproto-2.3.2.tar.gz
tar xzf inputproto-2.3.2.tar.gz
cd inputproto-2.3.2
./configure --prefix=/usr/local
make
make install
cd ..
```
### 3.5 xtrans
```bash

# 依赖于xorg-macros 已在上一步安装
export ACLOCAL_PATH=/usr/local/share/aclocal:$ACLOCAL_PATH
sudo cp /usr/local/share/aclocal/xorg-macros.m4 /usr/share/aclocal/

# wget https://master.dl.sourceforge.net/project/pisilinux/source/libXtrans-1.3.5.tar.xz
unzip libxtrans-xtrans-1.3.5.zip
cd libxtrans-xtrans-1.3.5
./autogen.sh --prefix=/usr/local
make 
make install
cd ..
```

### 3.6 libX11 核心库
```bash
wget https://www.x.org/releases/individual/lib/libX11-1.7.0.tar.gz
tar -xf libX11-1.7.0.tar.gz
cd libX11-1.7.0
./configure --prefix=/usr/local/ --enable-xcb --disable-gallium-llvm
make -j 8
make install
cd ..
```

---
## 4. mesa库依赖
（提供opengl2支持）
mesa编译好之后就有opengl2库了。
需要解决一大堆软件硬件以来。

### 4.1 glproto库
依赖xorg-macros，已经在上一步解决
```bash
wget https://www.x.org/releases/individual/proto/glproto-1.4.17.tar.gz
tar -xf glproto-1.4.17.tar.gz
cd glproto-1.4.17
./configure --prefix=/usr/local
make
make install
cd ..
# 验证
pkg-config --modversion glproto
```
### 4.2 xext 
notice: 不是xextproto
```bash
wget https://www.x.org/releases/individual/lib/libXext-1.3.5.tar.gz
tar -xf libXext-1.3.5.tar.gz
cd libXext-1.3.5
./configure --prefix=/usr/local
make -j 4
make install
cd ..
```
### 4.3 基础protocol包

####  randrproto

```bash
wget https://www.x.org/releases/individual/proto/randrproto-1.5.0.tar.gz
tar -xf randrproto-1.5.0.tar.gz
cd randrproto-1.5.0
./configure --prefix=/usr/local
make
make install
cd ..
```


#### renderproto
```bash
wget https://www.x.org/releases/individual/proto/renderproto-0.11.1.tar.gz
tar xzf renderproto-0.11.1.tar.gz
cd renderproto-0.11.1
./configure --prefix=/usr/local
make -j$(nproc)
make install
cd ..
```


#### xineramaproto

```bash
wget https://www.x.org/releases/individual/proto/xineramaproto-1.2.1.tar.gz
tar -xf xineramaproto-1.2.1.tar.gz
cd xineramaproto-1.2.1
./configure --prefix=/usr/local
make
make install
cd ..
```

#### damageproto

```bash
wget https://www.x.org/releases/individual/proto/damageproto-1.2.1.tar.gz
tar -xf damageproto-1.2.1.tar.gz
cd damageproto-1.2.1
./configure --prefix=/usr/local/
make
make install
cd ..
```

#### fixesproto

```bash
wget https://www.x.org/releases/individual/proto/fixesproto-5.0.tar.gz
tar -xf fixesproto-5.0.tar.gz
cd fixesproto-5.0
./configure --prefix=/usr/local/
make
make install
cd ..
```

#### dri2proto

```bash
wget https://www.x.org/releases/individual/proto/dri2proto-2.8.tar.gz
tar -xf dri2proto-2.8.tar.gz
cd dri2proto-2.8
./configure --prefix=/usr/local/
make
make install
cd ..
```

#### dri3proto

```bash
wget https://www.x.org/releases/individual/proto/dri3proto-1.0.tar.gz
tar -xf dri3proto-1.0.tar.gz
cd dri3proto-1.0
./configure --prefix=/usr/local/
make 
make install
cd ..
```

#### presentproto

```bash
wget https://www.x.org/releases/individual/proto/presentproto-1.0.tar.gz
tar -xf presentproto-1.0.tar.gz
cd presentproto-1.0
./configure --prefix=/usr/local/
make install
cd ..
```
#### libxshmfence

```bash
wget https://www.x.org/releases/individual/lib/libxshmfence-1.3.tar.gz
tar -xf libxshmfence-1.3.tar.gz
cd libxshmfence-1.3
./configure --prefix=/usr/local/
make
make install
cd ..
```



### 4.4. GPU支持
（聊胜于无， centos5没啥GPU支持）

#### libpciaccess

> libdrm 的依赖，必须先编译。

```bash
wget https://www.x.org/releases/individual/lib/libpciaccess-0.13.5.tar.gz
tar -xf libpciaccess-0.13.5.tar.gz
cd libpciaccess-0.13.5
./configure --prefix=/usr/local/
make -j$(nproc)
make install
cd ..
```

#### libdrm

> 依赖：libpciaccess

```bash
wget https://dri.freedesktop.org/libdrm/libdrm-2.4.75.tar.gz
tar -xf libdrm-2.4.75.tar.gz
cd libdrm-2.4.75

# 旧 glibc 兼容性修复
export CFLAGS="-DO_CLOEXEC=0 $CFLAGS"
export CXXFLAGS="-DO_CLOEXEC=0 $CXXFLAGS"

./configure --prefix=/usr/local/ --enable-static=yes --enable-shared=yes
make -j$(nproc)
make install
cd ..
```


---
## 5. X11扩展库

mesa、glfw的依赖
> 以下库按依赖顺序排列，必须依次编译。

### 5.1 libXrender

```bash
wget https://www.x.org/releases/individual/lib/libXrender-0.9.10.tar.gz
tar -xf libXrender-0.9.10.tar.gz
cd libXrender-0.9.10
./configure --prefix=/usr/local
make
make install
cd ..
```


### 5.2 libXdamage

> 依赖：xfixes, damageproto

```bash
wget https://www.x.org/releases/individual/lib/libXdamage-1.1.7.tar.gz
tar -xf libXdamage-1.1.7.tar.gz
cd libXdamage-1.1.7
./configure --prefix=/usr/local/
make
make install
cd ..
```

### 5.3 libXfixes

> 依赖：x11 >= 1.6, fixesproto, xextproto >= 7.0.99.1

```bash
wget https://www.x.org/releases/individual/lib/libXfixes-5.0.3.tar.bz2
tar -xjf libXfixes-5.0.3.tar.bz2
cd libXfixes-5.0.3
./configure --prefix=/usr/local/
make
make install
cd ..
```

### 5.4 libXrandr

> 依赖：xrender, randrproto

```bash
wget https://www.x.org/releases/individual/lib/libXrandr-1.5.2.tar.gz
tar -xf libXrandr-1.5.2.tar.gz
cd libXrandr-1.5.2
./configure --prefix=/usr/local/
make -j$(nproc)
make install
cd ..
```

### 5.5 libXcursor

> 依赖：xrender, xfixes, xrandr

```bash
wget https://www.x.org/releases/individual/lib/libXcursor-1.2.0.tar.gz
tar -xf libXcursor-1.2.0.tar.gz
cd libXcursor-1.2.0
./configure --prefix=/usr/local
make
make install
cd ..
```
### 5.6 libXinerama

> 依赖：xineramaproto

```bash
wget https://www.x.org/releases/individual/lib/libXinerama-1.1.4.tar.gz
tar -xf libXinerama-1.1.4.tar.gz
cd libXinerama-1.1.4
./configure --prefix=/usr/local
make
make install
cd ..
```
### 5.7 libXi

> 依赖：x11, inputproto, xext

```bash
wget https://www.x.org/releases/individual/lib/libXi-1.7.10.tar.gz
tar -xf libXi-1.7.10.tar.gz
cd libXi-1.7.10
./configure --prefix=/usr/local --with-x-includes=/usr/local/include --with-x-libraries=/usr/local/lib
make -j4
make install
cd ..
```
---

## 6. 编译 Mesa (OpenGL)

> Mesa 提供 OpenGL 支持，需要编译两次：一次动态库，一次静态库。
> 
> 依赖：glproto, xext, xcb, libdrm, dri2proto, dri3proto, presentproto, libxshmfence, xfixes, xdamage

### 6.1 下载 Mesa

```bash
wget https://archive.mesa3d.org/older-versions/17.x/mesa-17.0.0.tar.gz
tar -xf mesa-17.0.0.tar.gz
cd mesa-17.0.0
```

### 6.2 编译动态库

```bash
mkdir build_shared && cd build_shared
../configure --prefix=/usr/local/ \
    --with-gallium-drivers=svga,swrast \
    --disable-gallium-llvm
make -j4
make install
cd ..
```

### 6.3 编译静态库

```bash
mkdir build_static && cd build_static
../configure --prefix=/usr/local/ \
    --enable-static \
    --disable-shared \
    --disable-dri \
    --disable-dri3 \
    --disable-glx \
    --disable-gles1 \
    --disable-gles2 \
    --disable-egl \
    --with-platforms=x11,drm \
    --disable-gbm \
    --with-gallium-drivers=svga,swrast
make -j4
make install
cd ..
```
### 6.4 F_DUPFD_CLOEXEC’ undeclared

见第八节

---

## 7. 编译 GLFW3

> 依赖：x11, xrandr, xcursor, xi, xinerama, mesa

```bash
wget https://github.com/glfw/glfw/releases/download/3.3.8/glfw-3.3.8.zip
unzip glfw-3.3.8.zip
cd glfw-3.3.8
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/ -DBUILD_SHARED_LIBS=ON
make -j4
make install
cd ../..
```
error: ‘IN_NONBLOCK’ undeclared 见下一节

---

## 8. 常见问题修复

### 8.1 `F_DUPFD_CLOEXEC` 未定义（旧 glibc 兼容）

如果在编译 Mesa 时遇到如下错误：

```
error: 'F_DUPFD_CLOEXEC' undeclared (first use in this function)
```

在相关源文件头部添加：

```c
#ifndef F_DUPFD_CLOEXEC
#define F_DUPFD_CLOEXEC F_DUPFD   /* fallback to F_DUPFD for old glibc */
#endif
```

受影响的文件通常包括：
- `src/egl/drivers/dri2/platform_drm.c`
- `src/gallium/winsys/svga/drm/vmw_screen.c`
- `src/gallium/state_trackers/dri/dri2.c`

### 8.2 `IN_NONBLOCK` / `IN_CLOEXEC` 未定义（GLFW 旧系统兼容）

如果使用 GLFW 3.1.x 或更旧版本，在旧系统上编译 `linux_joystick.c` 时可能遇到：

```
error: 'IN_NONBLOCK' undeclared
error: 'IN_CLOEXEC' undeclared
```

将以下代码：

```c
_glfw.linux_js.inotify = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
```

替换为：

```c
_glfw.linux_js.inotify = inotify_init();  // 老版本 glibc 可用
if (_glfw.linux_js.inotify >= 0)
{
    // 设置非阻塞
    int flags = fcntl(_glfw.linux_js.inotify, F_GETFL, 0);
    fcntl(_glfw.linux_js.inotify, F_SETFL, flags | O_NONBLOCK);

    // 设置 close-on-exec
    flags = fcntl(_glfw.linux_js.inotify, F_GETFD, 0);
    fcntl(_glfw.linux_js.inotify, F_SETFD, flags | FD_CLOEXEC);
}
```

或者考虑使用 GLFW 3.0.4 等更旧的版本：
https://github.com/glfw/glfw/tree/3.0.4/src

---

## 9. 制作 GCC sysroot

编译完成后，可以制作 sysroot 供交叉编译使用：

```bash
sudo yum install rsync

rsync -avR \
    --exclude='tmp/*' \
    --exclude='proc/*' \
    --exclude='/sys/*' \
    --exclude='dev/*' \
    --exclude='opt/*' \
    --exclude='usr/etc/*' \
    --exclude='usr/games/*' \
    --exclude='usr/kerberos/*' \
    --exclude='usr/log/*' \
    --exclude='usr/sbin/*' \
    --exclude='usr/src/*' \
    --exclude='usr/X11R6/*' \
    /usr /include /lib /lib64 \
    /home/test/gcc/sysroot-centos511_withopengl/root
```

---

## 附录：依赖关系速查表

| 包名 | 直接依赖 |
|------|----------|
| util-macros | 无 |
| xproto | 无 |
| xcb-proto | 无 |
| xextproto | 无 |
| inputproto | 无 |
| randrproto | 无 |
| xineramaproto | 无 |
| glproto | util-macros |
| damageproto | 无 |
| fixesproto | 无 |
| dri2proto | 无 |
| dri3proto | 无 |
| presentproto | 无 |
| libxcb | xcb-proto, xproto |
| libpciaccess | 无 |
| libdrm | libpciaccess |
| libxshmfence | 无 |
| libX11 | xcb, xproto, xextproto |
| libXext | x11, xextproto |
| libXfixes | x11 >= 1.6, fixesproto, xextproto |
| libXdamage | xfixes, damageproto |
| libXrender | 无 |
| libXrandr | xrender, randrproto |
| libXcursor | xrender, xfixes, xrandr |
| libXi | x11, inputproto, xext |
| libXinerama | xineramaproto |
| Mesa | glproto, xext, xcb, libdrm, dri2proto, dri3proto, presentproto, libxshmfence, xfixes, xdamage |
| GLFW3 | x11, xrandr, xcursor, xi, xinerama, mesa |
