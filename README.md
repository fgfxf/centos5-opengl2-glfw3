# Complete Guide to Building GLFW3 + OpenGL2 on CentOS 5

<div align="center">

![CodeQL](https://github.com/serge1/ELFIO/workflows/CodeQL/badge.svg)
![Viewer](https://komarev.com/ghpvc/?username=fgfxf-centos5-opengl2-glfw3)
![Static Badge](https://img.shields.io/badge/License-MPL2.0-orange)

</div>

[中文说明](README_cn.md "chinese_readme")

This enables ImGui to run on CentOS 5.

Copyright 2026 fgfxf

> **Important: Please follow the order in this document strictly when compiling from source, otherwise compilation will fail due to missing dependencies.**

---

This project is sponsored by Qihoo 360.

## Table of Contents

- [1. Environment Preparation](#1-environment-preparation)
- [2. XCB Libraries](#2-xcb-libraries)
- [3. X11 Dependencies](#3-x11-dependencies)
- [4. Mesa Library Dependencies](#4-mesa-library-dependencies)
- [5. X11 Extension Libraries](#5-x11-extension-libraries)
- [6. Building Mesa (OpenGL)](#6-building-mesa-opengl)
- [7. Building GLFW3](#7-building-glfw3)
- [8. Common Issues and Fixes](#8-common-issues-and-fixes)
- [9. Creating a GCC Sysroot](#9-creating-a-gcc-sysroot)
- [Appendix: Dependency Quick Reference](#appendix-dependency-quick-reference)

---

## 1. Environment Preparation

## 1.1 System Environment

- A CentOS 5 system with internet access (can be a Docker container)
- Includes Red Hat's devtoolset-2 compatible compiler (GCC 4.8.x compiler)
- CentOS 5 devtoolset-2 repository: https://linuxsoft.cern.ch/cern/devtoolset/
- devtoolset-2 allows GCC 4.8.x compiled binaries to be compatible with CentOS 5 (GLIBC-2.5)

### 1.2 Installing pthread-stubs (Fixes missing pthread stub during Mesa compilation)

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

### 1.3 General pkg-config Verification
All components are installed to `/usr/local`:
```
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:$PKG_CONFIG_PATH
pkg-config --modversion pthread-stubs
```
It should display:
```
0.3
```
> The same applies to other components.

> **Unless otherwise noted, each component will normally compile both shared and static libraries.**

> **If `make` does not use `-j`, it means the make command may only generate a few header files without an actual compilation process.**

### 1.4 Upgrading autoconf
Except for libXtrans (an X11 dependency) which uses autoconf, all others use configure scripts.
```bash
wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz
tar xzf autoconf-2.71.tar.gz
cd autoconf-2.71

./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
/usr/local/bin/autoconf --version
# Should output 2.71 or higher
```
### 1.5 Python 2.5 or Higher
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

## 2. XCB Libraries

These are dependencies for X11 and Mesa.
### 2.1 XCB Protocol (xcb-proto)
```bash
wget https://www.x.org/releases/individual/proto/xcb-proto-1.14.1.tar.gz
tar -xf xcb-proto-1.14.1.tar.gz
cd xcb-proto-1.14.1
./configure --prefix=/usr/local
make
make install
cd ..
```
### 2.2 Fixing xcb-proto Bug
(You can also use another version where the bug may already be fixed.)
`Variable 'pc_sysrootdir' not defined in '/usr/local/lib/pkgconfig/xcb-proto.pc'`
Missing `pc_sysrootdir`, needs to be added manually:
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
### 2.3 xproto Dependency
```bash
wget https://www.x.org/releases/individual/proto/xproto-7.0.31.tar.gz
tar xvf xproto-7.0.31.tar.gz
cd xproto-7.0.31
./configure --prefix=/usr/local/
make
make install
cd ..
```
### 2.4 xau Dependency

```bash
wget https://www.x.org/releases/individual/lib/libXau-1.0.9.tar.gz
tar xzf libXau-1.0.9.tar.gz
cd libXau-1.0.9
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
cd ..
```
### 2.5 libxcb Core Library

```bash
wget https://www.x.org/releases/individual/lib/libxcb-1.14.tar.gz
tar -xf libxcb-1.14.tar.gz
cd libxcb-1.14
./configure --prefix=/usr/local
make
make install
cd ..
```
If errors occur:
1. Check if `/usr/local/lib/pkgconfig/xcb-proto.pc` path is correct.
pkg-config --modversion  xcb
2:
    from xcbgen.state import Module
ImportError: No module named xcbgen.state
Set environment variable:
find / | grep  xcbgen.state
Check the xcbgen path, then:
export PYTHONPATH=/usr/local/lib/python2.7/site-packages:$PYTHONPATH

---
## 3. X11 Dependencies

No package 'xextproto' found
No package 'xtrans' found
No package 'kbproto' found
No package 'inputproto' found
Depends on xcb, which was resolved in the previous step.

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

### 3.2 xorg Base Macros util-macros (xorg-macros)
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
# Download XInput2 proto headers
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

# Depends on xorg-macros, installed in the previous step
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

### 3.6 libX11 Core Library
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
## 4. Mesa Library Dependencies

(Provides OpenGL2 support)
Once Mesa is compiled, the OpenGL2 library will be available.
Needs to resolve a large number of software and hardware dependencies.

### 4.1 glproto Library
Depends on xorg-macros, which was resolved in the previous step.
```bash
wget https://www.x.org/releases/individual/proto/glproto-1.4.17.tar.gz
tar -xf glproto-1.4.17.tar.gz
cd glproto-1.4.17
./configure --prefix=/usr/local
make
make install
cd ..
# Verify
pkg-config --modversion glproto
```
### 4.2 xext 
Notice: This is not xextproto.
```bash
wget https://www.x.org/releases/individual/lib/libXext-1.3.5.tar.gz
tar -xf libXext-1.3.5.tar.gz
cd libXext-1.3.5
./configure --prefix=/usr/local
make -j 4
make install
cd ..
```
### 4.3 Base Protocol Packages

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



### 4.4. GPU Support

(Better than nothing; CentOS 5 has limited GPU support.)

#### libpciaccess

> Dependency for libdrm, must be compiled first.

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

> Dependency: libpciaccess

```bash
wget https://dri.freedesktop.org/libdrm/libdrm-2.4.75.tar.gz
tar -xf libdrm-2.4.75.tar.gz
cd libdrm-2.4.75

# Old glibc compatibility fix
export CFLAGS="-DO_CLOEXEC=0 $CFLAGS"
export CXXFLAGS="-DO_CLOEXEC=0 $CXXFLAGS"

./configure --prefix=/usr/local/ --enable-static=yes --enable-shared=yes
make -j$(nproc)
make install
cd ..
```


---
## 5. X11 Extension Libraries

Dependencies for Mesa and GLFW.
> The following libraries are listed in dependency order and must be compiled sequentially.

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

> Dependencies: xfixes, damageproto

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

> Dependencies: x11 >= 1.6, fixesproto, xextproto >= 7.0.99.1

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

> Dependencies: xrender, randrproto

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

> Dependencies: xrender, xfixes, xrandr

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

> Dependencies: xineramaproto

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

> Dependencies: x11, inputproto, xext

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

## 6. Building Mesa (OpenGL)

> Mesa provides OpenGL support and needs to be compiled twice: once for shared libraries, and once for static libraries.
> 
> Dependencies: glproto, xext, xcb, libdrm, dri2proto, dri3proto, presentproto, libxshmfence, xfixes, xdamage

### 6.1 Download Mesa

```bash
wget https://archive.mesa3d.org/older-versions/17.x/mesa-17.0.0.tar.gz
tar -xf mesa-17.0.0.tar.gz
cd mesa-17.0.0
```

### 6.2 Build Shared Libraries

```bash
mkdir build_shared && cd build_shared
../configure --prefix=/usr/local/ \
    --with-gallium-drivers=svga,swrast \
    --disable-gallium-llvm
make -j4
make install
cd ..
```

### 6.3 Build Static Libraries

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
### 6.4 `F_DUPFD_CLOEXEC` Undeclared

See Section 8.

---

## 7. Building GLFW3

> Dependencies: x11, xrandr, xcursor, xi, xinerama, mesa

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
error: `IN_NONBLOCK` undeclared. See the next section.

---

## 8. Common Issues and Fixes

### 8.1 `F_DUPFD_CLOEXEC` Undefined (Old glibc Compatibility)

If you encounter the following error when compiling Mesa:

```
error: 'F_DUPFD_CLOEXEC' undeclared (first use in this function)
```

Add the following to the top of the relevant source file:

```c
#ifndef F_DUPFD_CLOEXEC
#define F_DUPFD_CLOEXEC F_DUPFD   /* fallback to F_DUPFD for old glibc */
#endif
```

Affected files typically include:
- `src/egl/drivers/dri2/platform_drm.c`
- `src/gallium/winsys/svga/drm/vmw_screen.c`
- `src/gallium/state_trackers/dri/dri2.c`

### 8.2 `IN_NONBLOCK` / `IN_CLOEXEC` Undefined (GLFW Old System Compatibility)

If using GLFW 3.1.x or older, you may encounter the following when compiling `linux_joystick.c` on old systems:

```
error: 'IN_NONBLOCK' undeclared
error: 'IN_CLOEXEC' undeclared
```

Replace the following code:

```c
_glfw.linux_js.inotify = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
```

With:

```c
_glfw.linux_js.inotify = inotify_init();  // Available on older glibc versions
if (_glfw.linux_js.inotify >= 0)
{
    // Set non-blocking
    int flags = fcntl(_glfw.linux_js.inotify, F_GETFL, 0);
    fcntl(_glfw.linux_js.inotify, F_SETFL, flags | O_NONBLOCK);

    // Set close-on-exec
    flags = fcntl(_glfw.linux_js.inotify, F_GETFD, 0);
    fcntl(_glfw.linux_js.inotify, F_SETFD, flags | FD_CLOEXEC);
}
```

Or consider using an older version of GLFW such as 3.0.4:
https://github.com/glfw/glfw/tree/3.0.4/src

---

## 9. Creating a GCC Sysroot

After compilation is complete, you can create a sysroot for cross-compilation:

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

## Appendix: Dependency Quick Reference

| Package | Direct Dependencies |
|---------|---------------------|
| util-macros | None |
| xproto | None |
| xcb-proto | None |
| xextproto | None |
| inputproto | None |
| randrproto | None |
| xineramaproto | None |
| glproto | util-macros |
| damageproto | None |
| fixesproto | None |
| dri2proto | None |
| dri3proto | None |
| presentproto | None |
| libxcb | xcb-proto, xproto |
| libpciaccess | None |
| libdrm | libpciaccess |
| libxshmfence | None |
| libX11 | xcb, xproto, xextproto |
| libXext | x11, xextproto |
| libXfixes | x11 >= 1.6, fixesproto, xextproto |
| libXdamage | xfixes, damageproto |
| libXrender | None |
| libXrandr | xrender, randrproto |
| libXcursor | xrender, xfixes, xrandr |
| libXi | x11, inputproto, xext |
| libXinerama | xineramaproto |
| Mesa | glproto, xext, xcb, libdrm, dri2proto, dri3proto, presentproto, libxshmfence, xfixes, xdamage |
| GLFW3 | x11, xrandr, xcursor, xi, xinerama, mesa |
