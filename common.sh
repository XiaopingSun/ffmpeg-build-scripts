#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 Bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# !======= shell 注释 =======

# 显示当前shell的所有变量(环境变量，自定义变量，与bash接口相关的变量)
set -e

# =====自定义字典实现======== #
# 各个源码的索引;(也为下载顺序,编译顺序)
ffmpeg=0
x264=1
fdkaac=2
mp3lame=3
x265=4
openssl=5

# 各个源码的名字
LIBS[ffmpeg]=ffmpeg
LIBS[x264]=x264
LIBS[fdkaac]=fdk-aac
LIBS[mp3lame]=mp3lame
LIBS[x265]=x265
LIBS[openssl]=ssl

# 各个源码对应的pkg-config中.pc的名字
LIBS_PKGS[ffmpeg]=ffmpeg
LIBS_PKGS[x264]=x264
LIBS_PKGS[fdkaac]=fdk-aac
LIBS_PKGS[mp3lame]=mp3lame
LIBS_PKGS[x265]=x265
LIBS_PKGS[openssl]=openssl

# # ffmpeg
# All_Resources[ffmpeg]=https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n4.4
# # x264
# All_Resources[x264]=https://code.videolan.org/videolan/x264/-/archive/stable/x264-stable.tar.gz
# # fdkaac
# All_Resources[fdkaac]=https://jaist.dl.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-2.0.0.tar.gz
# #mp3lame
# All_Resources[mp3lame]=https://jaist.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
# # x265
# All_Resources[x265]=https://github.com/videolan/x265/archive/refs/heads/master.zip
# # openssl
# All_Resources[openssl]=https://www.openssl.org/source/openssl-1.1.1d.tar.gz

# 外部库引入ffmpeg时的配置参数
# 这里必须要--enable-encoder --enable-decoder的方式开启libx264，libfdk_aac，libmp3lame
# 否则外部库无法加载到ffmpeg中
# libx264和mp3lame只提供编码功能，h264和mp3的解码是ffmpeg内置的库(--enable-decoder=h264和--enable-decoder=mp3float开启)
LIBS_PARAM[ffmpeg]=""
LIBS_PARAM[x264]="--enable-libx264 --enable-encoder=libx264"
LIBS_PARAM[fdkaac]="--enable-libfdk-aac --enable-encoder=libfdk_aac"
LIBS_PARAM[mp3lame]="--enable-libmp3lame --enable-encoder=libmp3lame"
LIBS_PARAM[x265]="--enable-libx265 --enable-encoder=libx265"
LIBS_PARAM[openssl]="--enable-openssl --enable-protocol=http --enable-protocol=https --enable-protocol=hls"
export LIBS_PARAM

# =====自定义字典实现======== #

# 平台
uname=`uname`
if [ $uname == "Darwin" ];then
export OUR_SED="sed -i '' "
else
export OUR_SED="sed -i"
fi

# 公用工具脚本路径
TOOLS=tools

function get_cpu_count() {
    if [ "$(uname)" == "Darwin" ]; then
        echo $(sysctl -n hw.physicalcpu)
    else
        echo $(nproc)
    fi
}

# 检查编译环境是否具备
function check_build_env
{
    echo_c "== check build env ! =="
    # 检查编译环境，比如是否安装 brew yasm gas-preprocessor.pl等等;
    # sh $TOOLS/check-build-env.sh 代表重新开辟一个新shell，是两个不同的shell进程了，互相独立，如果出错，不影响本shell
    #  . $TOOLS/check-build-env.sh 代表在本shell中执行该脚本，全局变量可以共享，如果出错，本shell也会退出。
    . $TOOLS/check-build-env.sh
    echo_c "==check build env success ok! =="
    echo -e ""
}


# tar命令解压本地源码
function tar_lib_sources_ifneeded() {

    mkdir -p extra
    for lib in $(echo ${!LIBS[*]})
    do

        if [ ! -d extra/${LIBS[$lib]} ] && [ ${LIBFLAGS[$lib]} == "TRUE" ];then
            echo_c "== tar ${LIBS[$lib]} base begin. =="
            echo "$extra and ${LIBS[$lib]}"
            . $TOOLS/local-tar-xz.sh extra ${LIBS[$lib]}
            echo_c "== tar ${LIBS[$lib]} base finish =="
        fi
    done
}

# 从本地copy源码
# $1 代表库的名称 ffmpeg x264
function copy_from_local() {

    # 平台对应的libsource目录下存在对应的源码目录，则默认已经有代码了，不拷贝了；如果要重新拷贝，先手动删除libsources下对应的源码
    if [ -d build/libsource/$1 ]; then
#        echo "== copy $3 $2 fork $1 == has exist return"
        return
    fi

    echo_c "== copy fork $1 =="
    mkdir -p build/libsource
    # -rf 拷贝指定目录及其所有的子目录下文件
    cp -rf extra/$1 build/libsource/$1
}

# ---- 供外部调用，检查编译环境和获取所有用于编译的源码 ------
# 参数为所有需要编译的平台 x86_64 arm64 等等；使用prepare_all ios x86_64 arm64;
# $* 的取值格式为 val1 val2 val3....valn 中间为空格隔开

prepare_all() {
    # 检查环境
    check_build_env

    tar_lib_sources_ifneeded

    # 代表从第一个参数之后开始的所有参数
    for lib in $(echo ${!LIBS[*]})
    do
        if [[ -d extra/${LIBS[$lib]} ]] && [[ ${LIBFLAGS[$lib]} = "TRUE" ]];then
            if [[ ${LIBS[$lib]} = "ffmpeg" ]] && [[ $INTERNAL_DEBUG = "TRUE" ]];then
                # ffmpeg用内部自己研究的代码
                if [[ ! -d build/libsource/ffmpeg ]];then
                    echo_c "== copy fork ffmpeg =="
                    mkdir -p build/libsource/ffmpeg
                    cp -rf /Users/apple/devoloper/mine/ffmpeg/ffmpeg-source/ build/libsource/ffmpeg
                fi

                continue
            fi

            # 正常拷贝库
            copy_from_local ${LIBS[$lib]}

        fi
    done
}

function rm_build()
{
    if [ $2 = "all" ];then
        rm -rf build/$1-*
        echo_r "clean all success!"
        return
    fi
    if [ $2 = "cache" ];then
        rm -rf build/libsource
        echo_r "clean cache success!"
        return
    fi
    rm -rf build/$1-$3/$2
    echo_r "clean $1-$3/$2 success!"
}

# 版本要和实际下载地址对应;cat > .... << EOF 代表将两个EOF之间内容输入到指定文件
function create_mp3lame_package_config() {
    local pkg_path="$1"
    local prefix_path="$2"

    cat > "${pkg_path}/mp3lame.pc" << EOF
prefix=${prefix_path}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: lame mp3 encoder library
Version: 3.100

Requires:
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
EOF
}

function create_x265_package_config() {
    local pkg_path="$1"
    local prefix_path="$2"

    cat > "${pkg_path}/x265.pc" << EOF
prefix=${prefix_path}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libx265
Description: H.265/HEVC video encoder
Version: 3.4

Requires:
Libs: -L\${libdir} -lx265
Libs.private: -lc++ -ldl
Cflags: -I\${includedir}
EOF
}

#  echo -e "\033[30m 黑色字 \033[0m"
#　echo -e "\033[31m 红色字 \033[0m"
#　echo -e "\033[32m 绿色字 \033[0m"
#　echo -e "\033[33m 黄色字 \033[0m"
#　echo -e "\033[34m 蓝色字 \033[0m" 
#　echo -e "\033[35m 紫色字 \033[0m" 
#　echo -e "\033[36m 天蓝字 \033[0m" 
#　echo -e "\033[37m 白色字 \033[0m" 
function echo_r () {
        echo -e "\033[1;31m $1 \033[0m"
}

function echo_g () {
        echo -e "\033[1;32m $1 \033[0m"
}

function echo_y () {
        echo -e "\033[1;33m $1 \033[0m"
}

function echo_b () {
        echo -e "\033[1;34m $1 \033[0m"
}

function echo_p () {
        echo -e "\033[1;35m $1 \033[0m"
}

function echo_c () {
        echo -e "\033[1;36m $1 \033[0m"
}