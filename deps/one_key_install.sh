#!/bin/sh
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD_WHITE='\033[1;37m'
RESET='\033[0m'  # 结束颜色

echo -e "${BOLD_WHITE}#
# fgfxf 
# one key compile and install opengl2 glfw3 for centos 5 
# need gcc/g++ 4.8  (devtoolsets-2 support by RedHat)
#${RESET}"
# 设置脚本在遇到错误时退出
set -e
user_path="/usr/local"

# 函数：询问安装路径
ask_install_path() {
    local default_path=$user_path
    read -p "please input install path [default: $default_path]:" user_path
    # 如果用户直接按回车，则使用默认路径
    if [ -z "$user_path" ]; then
        user_path="$default_path"
    fi
     # 确保路径以 / 结尾
    [[ "${user_path}" != */ ]] && user_path="${user_path}/"
    echo "will install into :$user_path"
}


# check gcc 
function check_gcc_version(){
    if command -v gcc >/dev/null 2>&1; then
        local GCC_VERSION=`gcc -dumpversion`
        local GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d. -f1)
        local GCC_MINOR=$(echo "$GCC_VERSION" | cut -d. -f2)
        # 判断是否大于 4.8
        if [ "$GCC_MAJOR" -lt 4 ] || { [ "$GCC_MAJOR" -eq 4 ] && [ "$GCC_MINOR" -lt 8 ]; }; then
            echo "GCC version $GCC_VERSION is too old. Require > 4.8.0"
            return 1
        else
            echo "GCC version $GCC_VERSION is OK"
            return 0
        fi
    else   
        echo "GCC not installed"
        return 1
    fi
}
# check python
function check_python_version() {
    if command -v python >/dev/null 2>&1; then
        # 获取主版本和次版本
        local PY_VERSION=$(python -c 'import sys; print "%d.%d" % (sys.version_info[0], sys.version_info[1])' 2>/dev/null)
        local PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
        local PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)

        # 判断是否 >= 2.5
        if [ "$PY_MAJOR" -lt 2 ] || { [ "$PY_MAJOR" -eq 2 ] && [ "$PY_MINOR" -lt 5 ]; }; then
            echo "Python version $PY_VERSION is too old. Require >= 2.5"
            return 1
        else
            echo "Python version $PY_VERSION is OK"
            return 0
        fi
    else
        echo "Python is not installed"
        return 1
    fi
}

function check_autoconfig_version(){
    local version=$(autoconf -V | head -n1 | awk '{print $4}')
    echo "Detected autoconf version: $version"
    # 用 awk 比较版本号
    local required_version="2.60"
    local is_ok=$(awk -v v1="$version" -v v2="$required_version" 'BEGIN {
        split(v1,a,"."); split(v2,b,".");
        if(a[1]>b[1]) {print 1; exit}
        if(a[1]<b[1]) {print 0; exit}
        if(a[2]>=b[2]) {print 1; exit} else {print 0; exit}
    }')

    if [ "$is_ok" -eq 1 ]; then
        echo "autoconf ${version} is OK (>= $required_version)"
        return 0
    else
        echo "autoconf ${version} is too low (< $required_version)"
        return 1
    fi


}

# 函数：写多行文本到指定文件
# 参数1：目标文件路径
# 参数2：多行内容字符串
write_override_file() {
    local target_file="$1"
    local content="$2"

    # 创建目录
    mkdir -p "$(dirname "$target_file")"

    # 写入文件
    cat > "$target_file" <<EOF
$content
EOF

    echo "文件 $target_file 创建完成"
}

#
function install_python2_7(){
    echo "Installing python2.7"
    local install_dir="${user_path}/python2.7"
     # 解压源码
    tar xzf Python-2.7.18.tgz
    cd Python-2.7.18 || { echo "Failed to enter Python-2.7.18 directory"; return 1; }
     # 配置安装
    ./configure --prefix="$install_dir"
      # 编译安装
    make -j"$(nproc)" || { echo "python 2.7 make failed"; return 1; }
    make install || { echo "Python 2.7 install failed"; return 1; }

    # 更新 PATH 和 PYTHONPATH
    export PATH="$install_dir/bin:$PATH"
    export PYTHONPATH="$install_dir/lib/python2.7/site-packages:$PYTHONPATH"
    
    # 验证安装
    if ! check_python_version ; then
        echo "install python 2.7 failed."
        return 1
    fi
    echo "Python 2.7 installed at $install_dir"
    cd ..
}

function export_pkg_config(){
    echo "setting evironment variables"
    # 假设 user_path 已经定义，并且以 / 结尾
    local pkg_path1="${user_path}lib/pkgconfig"
    local pkg_path2="${user_path}share/pkgconfig"
    # 判断 PKG_CONFIG_PATH 是否包含 pkg_path1
    if ! echo "$PKG_CONFIG_PATH" | grep -q "$pkg_path1"; then
        # 如果没有则追加到前面
        export PKG_CONFIG_PATH="${pkg_path1}:${pkg_path2}:${PKG_CONFIG_PATH}"
    fi
    # 打印确认
    echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
}

function check_pkgmodule_exist(){
  local module_name="$1"
    echo -e "${BLUE}checking pkg-config module ${module_name}..."
    # 使用 pkg-config 检查版本
    if pkg-config --modversion "$module_name" >/dev/null 2>&1; then
        # 存在，获取版本号
        local version
        version=$(pkg-config --modversion "$module_name")
        echo "Module ${module_name} found, version: $version"
        echo -e "${RESET}"
        return 0
    else
        echo "Module ${module_name} NOT found!"
        echo -e "${RESET}"
        return 1
    fi
    echo -e "${RESET}"
}

function check_pkgmodule_version(){
    local module_name="$1"
    local required_version="$2"

    echo -e "${BLUE} Checking pkg-config module ${module_name}..."

    # 检查模块是否存在
    if ! pkg-config --modversion "$module_name" >/dev/null 2>&1; then
        echo "Module ${module_name} NOT found!"
        echo -e "${RESET}"
        return 1
    fi

    local version
    version=$(pkg-config --modversion "$module_name")
    echo "Module ${module_name} found, version: $version"

    # 如果没有指定要求版本，直接返回成功
    [ -z "$required_version" ] && echo -e "${RESET}" && return 0

    # 版本比较函数
    function ver_ge() {
        # 参数1：当前版本 参数2：要求版本
        local IFS=.
        local i ver1=($1) ver2=($2)
        # 填充缺失的次级版本为0
        for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
        for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done

        for i in 0 1 2; do
            if ((10#${ver1[i]} > 10#${ver2[i]})); then
                echo -e "${RESET}"
                return 0
            elif ((10#${ver1[i]} < 10#${ver2[i]})); then
                echo -e "${RESET}"
                return 1
            fi
        done
        echo -e "${RESET} "
        return 0  # 相等
    }

    if ver_ge "$version" "$required_version"; then
        echo -e "${GREEN} Version $version >= required $required_version ✅"
        echo -e "${RESET}"
        return 0
    else
        echo -e "${RED} Version $version < required $required_version ❌"
        echo -e "${RESET}"
        return 1
    fi
}
function install_pthread_stubs(){
    if ! check_pkgmodule_exist "pthread-stubs" ; then
        pthread_content="prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: pthread-stubs
Description: Dummy pthread-stubs
Version: 0.3
Cflags: -I\${includedir}
Libs: -lpthread"
        write_override_file "${user_path}/lib/pkgconfig/pthread-stubs.pc" "$pthread_content"
    fi

}

function install_autoconfig(){
    echo "installing autoconf..."
    local autoconf_dir="${user_path}/bin/"
    tar xzf autoconf-2.71.tar.gz
    cd autoconf-2.71  || { echo "Failed to enter autoconf-2.71  directory"; return 1; }

    ./configure --prefix=/usr/local
    make -j$(nproc) || { echo "make autoconf failed."; return 1; }
    make install || { echo "make insatll autoconf failed."; return 1; }
    export PATH="$autoconf_dir:$PATH"
    cd ..
}
#  参数1 tar.gz 文件名
function install_tar_package() {
    local tar_file="$1"
    local params=("${@:2}")      # 从第二个参数开始的所有参数
    local install_prefix="${user_path}"  # 安装路径 

    if [ -z "$tar_file" ]; then
        echo "Usage: install_tar_package <tar.gz file> [install_prefix]"
        return 1
    fi

    if [ ! -f "$tar_file" ]; then
        echo "Error: file '$tar_file' not found!"
        return 1
    fi

    # 获取解压后的目录名（去掉 .tar.gz）
    local dir_name
    dir_name=$(basename "$tar_file" .tar.gz)

    echo "Extracting $tar_file ..."
    tar -xf "$tar_file" || { echo "Error: failed to extract $tar_file"; exit 1; }

    if [ ! -d "$dir_name" ]; then
        echo "Error: directory '$dir_name' not found after extraction!"
        exit 1
    fi

    cd "$dir_name" || { echo "Error: cannot enter directory '$dir_name'"; exit 1; }

    echo "Running configure with prefix=$install_prefix ..."
    echo "Running configure: ./configure --prefix=$install_prefix ${params[*]}"
    ./configure --prefix="$install_prefix"  "${params[@]}" || { echo "Error: configure failed"; cd ..; exit 1; }

    echo "Running make ..."
    make || { echo "Error: make ${tar_file} failed"; cd ..; exit 1; }

    echo "Running make install ..."
    make install || { echo "Error: make install ${tar_file} failed"; cd ..; exit 1; }

    cd .. || exit 1
    echo "Installation of $tar_file completed successfully!"
}

function install_xcb(){

    if ! check_pkgmodule_version "xcb-proto" "1.14.1" ; then 
        install_tar_package "xcb-proto-1.14.1.tar.gz"
        xcb_proto_content="prefix=${user_path}
exec_prefix=\${prefix}
datarootdir=\${prefix}/share
datadir=\${datarootdir}
libdir=\${exec_prefix}/lib
xcbincludedir=${user_path}/share/xcb
pythondir=\${prefix}/lib/python2.7/site-packages

Name: XCB Proto
Description: X protocol descriptions for XCB
Version: 1.14.1
"
    write_override_file "${user_path}/lib/pkgconfig/xcb-proto.pc" "${xcb_proto_content}"

    fi

    if ! check_pkgmodule_version "xproto" "7.0.31"; then
        install_tar_package "xproto-7.0.31.tar.gz"
    fi

    if ! check_pkgmodule_version "xau" "1.0.9" ; then
        install_tar_package "libXau-1.0.9.tar.gz"
    fi

    if ! check_pkgmodule_version "xcb" "1.14" ; then
        install_tar_package "libxcb-1.14.tar.gz"
    fi

}


function install_x11_dependency(){
    if ! check_pkgmodule_version "xextproto" "7.2.1" ;then 
        install_tar_package "xextproto-7.2.1.tar.gz"
    fi

    if ! check_pkgmodule_version "xorg-macros" "1.19.3" ;then 
        install_tar_package "util-macros-1.19.3.tar.gz"
        export ACLOCAL_PATH="${user_path}/share/aclocal:$ACLOCAL_PATH"
        cp ${user_path}/share/aclocal/xorg-macros.m4 /usr/share/aclocal/ || { echo "exist m4 file." ; }
    fi

    if ! check_pkgmodule_version "kbproto" "1.0.7" ; then
        install_tar_package "kbproto-1.0.7.tar.gz"
    fi

    if ! check_pkgmodule_version "inputproto" "2.3.2" ; then
        install_tar_package "inputproto-2.3.2.tar.gz"
    fi

    if ! check_pkgmodule_version "xtrans" "1.3.5" ; then
        unzip libxtrans-xtrans-1.3.5.zip
        cd libxtrans-xtrans-1.3.5 || { echo "Can't find dir libxtrans-xtrans-1.3.5" ; exit 1 ;}
        ./autogen.sh --prefix=${user_path} || { echo "Can't run autogen.sh in libXtrans" ; exit 1 ;}
        make  || { echo "make error !  libXtrans " ; exit 1 ;}
        make install || { echo "make install error ! libXtrans" ; exit 1 ; }
        cd ..
    fi

    if ! check_pkgmodule_version "x11" "1.7.0" ; then 
        install_tar_package "libX11-1.7.0.tar.gz"  --enable-xcb  --disable-gallium-llvm 
        if ! check_pkgmodule_version "x11-xcb" "1.7.0" ; then
            echo "something wrong !"
            exit 1
        fi
    fi
}


function install_mesa_dependency(){
    if ! check_pkgmodule_version "glproto" "1.4.17" ; then
        install_tar_package "glproto-1.4.17.tar.gz"
    fi

    if ! check_pkgmodule_version "xext" "1.3.5" ; then
        install_tar_package "libXext-1.3.5.tar.gz"
    fi

    if ! check_pkgmodule_version "randrproto" "1.5.0" ; then 
        install_tar_package "randrproto-1.5.0.tar.gz"
    fi    

    if ! check_pkgmodule_version "renderproto" "0.11.1" ; then
        install_tar_package "renderproto-0.11.1.tar.gz"
    fi

    if ! check_pkgmodule_version "xineramaproto" "1.2.1" ; then
        install_tar_package "xineramaproto-1.2.1.tar.gz"
    fi

    if ! check_pkgmodule_version "damageproto" "1.2.1" ; then
        install_tar_package "damageproto-1.2.1.tar.gz"
    fi

    if ! check_pkgmodule_version "fixesproto" "5.0" ; then
        install_tar_package "fixesproto-5.0.tar.gz"
    fi

    if ! check_pkgmodule_version "dri2proto" "2.8" ; then 
        install_tar_package "dri2proto-2.8.tar.gz"
    fi

    if ! check_pkgmodule_version "dri3proto" "1.0"; then 
        install_tar_package "dri3proto-1.0.tar.gz"
    fi

    if ! check_pkgmodule_version "presentproto" "1.0" ; then
        install_tar_package "presentproto-1.0.tar.gz"
    fi

    if ! check_pkgmodule_version "xshmfence" "1.3" ; then
        install_tar_package "libxshmfence-1.3.tar.gz"
    fi
}

function install_softGPU_support(){
    if ! check_pkgmodule_version "pciaccess" "0.13.5" ; then
        install_tar_package "libpciaccess-0.13.5.tar.gz"
    fi

    if ! check_pkgmodule_version "libdrm" "2.4.75" ; then
        export CFLAGS="-DO_CLOEXEC=0 $CFLAGS"
        export CXXFLAGS="-DO_CLOEXEC=0 $CXXFLAGS"
        install_tar_package "libdrm-2.4.75.tar.gz" --enable-static=yes --enable-shared=yes
    fi
}

function install_x11_extension(){
    if ! check_pkgmodule_version "xrender" "0.9.10"; then
        install_tar_package "libXrender-0.9.10.tar.gz"
    fi

    if ! check_pkgmodule_version "xfixes" "5.0.3"; then
        install_tar_package "libXfixes-5.0.3.tar.gz"
    fi

    if ! check_pkgmodule_version "xdamage" "1.1.7"; then
        install_tar_package  "libXdamage-1.1.7.tar.gz"
    fi


    if ! check_pkgmodule_version "xrandr" "1.5.2"; then
        install_tar_package "libXrandr-1.5.2.tar.gz"
    fi

    if ! check_pkgmodule_version "xcursor" "1.2.0"; then
        install_tar_package "libXcursor-1.2.0.tar.gz"
    fi

    if ! check_pkgmodule_version "xinerama" "1.1.4"; then
        install_tar_package "libXinerama-1.1.4.tar.gz"
    fi

    if ! check_pkgmodule_version "xi" "1.7.10"; then
        install_tar_package "libXi-1.7.10.tar.gz" --with-x-includes=${user_path}/include --with-x-libraries=${user_path}/lib
    fi
}

function install_mesa_opengl(){

    if ! [ -f ${user_path}/lib/libGL.so ] || ! check_pkgmodule_version "glesv2" "7.0" ; then
        echo -e "${YELLOW} Mesa OpenGL dynamic library not found. ${RESET}"
        tar -xf mesa-17.0.0.tar.gz
        cd mesa-17.0.0 || { echo "mesa-17.0.0 DIR not found! "; exit 1 ; }
        mkdir build_shared || { echo "build_shared exist! "; }
        cd build_shared
        export CPPFLAGS="-D_GNU_SOURCE -DO_CLOEXEC=0 -DF_DUPFD_CLOEXEC=0 $CPPFLAGS"
        export CFLAGS="-D_GNU_SOURCE -DO_CLOEXEC=0 -DF_DUPFD_CLOEXEC=0 $CFLAGS"
        export CXXFLAGS="-D_GNU_SOURCE -DO_CLOEXEC=0 -DF_DUPFD_CLOEXEC=0 $CXXFLAGS"
        ../configure --prefix=/usr/local/  --with-gallium-drivers=svga,swrast  --disable-gallium-llvm
        make -j4 
        make install
        cd ../../
    fi
}


function install_glfw3(){
    if ! check_pkgmodule_version "glfw3" "3" ; then
        if ! [ -d glfw-3.2.1 ] ; then 
            unzip glfw-3.2.1.zip
            cp fix_file.patch glfw-3.2.1
            cd glfw-3.2.1
            patch -p0 < fix_file.patch
            cd ../
        fi
        cd glfw-3.2.1
        mkdir build
        cd build
        cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/ -DBUILD_SHARED_LIBS=ON
        make -j4
        make install
        cd ../..
    fi
}
# main:
function main(){
    if ! check_gcc_version; then
        echo "GCC version check failed, exiting."
        exit 1
    fi
    ask_install_path
    if ! check_python_version; then
        if ! install_python2_7; then
            exit 1
        fi
    fi
    
    
    export_pkg_config
    install_pthread_stubs
    if ! check_autoconfig_version ;then
        if ! install_autoconfig ;then
            exit 1
        fi
    fi

    install_xcb
    install_x11_dependency
    install_mesa_dependency
    install_softGPU_support
    install_x11_extension
    install_mesa_opengl
    install_glfw3
}

# test or install single pkg
function testmain(){
    install_glfw3
}

# main
main
echo "End.."