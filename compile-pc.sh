#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
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

#----------
# $0 当前脚本的文件名
# $1 表示执行shell脚本时输入的第一个参数 比如./compile-ffmpeg-pc.sh arm64 x86_64 $1的值为arm64;$2的值为x86_64
# $# 传递给脚本或函数的参数个数。
# $* 传递给脚本或者函数的所有参数;
# $@ 传递给脚本或者函数的所有参数;
# 两者区别就是 不被双引号(" ")包含时，都以"$1" "$2" … "$n" 的形式输出所有参数。而"$*"表示"$1 $2 … $n";
# "$@"依然为"$1" "$2" … "$n"
# $$ 脚本所在的进程ID
# $? 上个命令的退出状态，或函数的返回值。一般命令返回值 执行成功返回0 失败返回1
set -e
. ./common.sh

#当前Linux/Windows/Mac操作系统的位数，如果是64位则填写x86_64，32位则填写x86
export FF_PC_ARCH="x86_64"

# 编译动态库，默认开启;FALSE则关闭动态库 编译静态库;动态库和静态库同时只能开启一个，建议采用动态库方式编译，因为静态方式编译存在相互引用的各个静态库因连接顺序不对导致编译错误的问题。
export FF_COMPILE_SHARED=FALSE
# 是否编译这些库;如果不编译将对应的值改为FALSE即可；如果ffmpeg对应的值为TRUE时，还会将其它库引入ffmpeg中，否则单独编译其它库
export LIBFLAGS=(
[ffmpeg]=TRUE [x264]=TRUE [fdkaac]=TRUE [mp3lame]=TRUE [x265]=TRUE [openssl]=TRUE
)

# 是否开启ffplay ffmpeg ffprobe的编译；默认关闭
export ENABLE_FFMPEG_TOOLS=FALSE

# 是否开启硬编解码；默认开启(tips:目前只支持mac的硬编解码编译)
export ENABLE_GPU=TRUE

UNI_BUILD_ROOT=`pwd`
FF_PC_TARGET=$1
FF_PC_ACTION=$2
export FF_PLATFORM_TARGET=$1

# 配置编译环境
set_toolchain_path()
{
    local ARCH=$1
    mkdir -p ${UNI_BUILD_ROOT}/build/$FF_PLATFORM_TARGET-$ARCH/pkgconfig
    export PKG_CONFIG_PATH=${UNI_BUILD_ROOT}/build/$FF_PLATFORM_TARGET-$ARCH/pkgconfig
    export STATIC_DYLMIC="--enable-static --disable-shared"
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
    export STATIC_DYLMIC="--disable-static --enable-shared"
    fi
}

real_do_compile()
{	
	CONFIGURE_FLAGS=$1
	lib=$2
	SOURCE=$UNI_BUILD_ROOT/build/libsource/$lib
    if [[ $lib = "x265" ]]; then
        SOURCE=$UNI_BUILD_ROOT/build/libsource/$lib/source
    fi
	PREFIX=$UNI_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib
	cd $SOURCE
	
	echo ""
	echo_c "build $lib $FF_PC_ARCH ......."
	echo_p "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
	echo_p "prefix:$PREFIX"
	echo ""

    set +e 
    make clean
    set -e
    
    if [[ $lib = "x265" ]]; then
         
        cmake -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX . || exit 1
        make && make install|| exit 1

        # cd -
        # local LIB_PATH=$PREFIX/lib
        # local INCLUDE_PATH=$PREFIX/include

        # mkdir -p $LIB_PATH
        # mkdir -p $INCLUDE_PATH

        # cd $SOURCE
        # cp ./libx265.a $LIB_PATH || exit 1
        # cp ./x265.h $INCLUDE_PATH || exit 1
        # cp ./x265_config.h $INCLUDE_PATH || exit 1


    elif [[ $lib = "ssl" ]]; then

        ./Configure \
            ${CONFIGURE_FLAGS} \
            darwin64-x86_64-cc \
            --prefix=$PREFIX
        
        make -j$(get_cpu_count) && make install_sw || exit 1        
    else

        ./configure \
            ${CONFIGURE_FLAGS} \
            --prefix=$PREFIX
            
        make -j$(get_cpu_count) && make install || exit 1
    fi

	if [ $lib = "mp3lame" ];then
        create_mp3lame_package_config "${PKG_CONFIG_PATH}" "${PREFIX}"
    elif [ $lib = "x265" ]; then
        create_x265_package_config "${PKG_CONFIG_PATH}" "${PREFIX}"
    else
        cp ./*.pc ${PKG_CONFIG_PATH} || exit 1
    fi

    echo ""
    echo_c "build $lib $FF_PC_ARCH success!"
    echo ""
    
    cd -
}

#编译x264
do_compile_x264()
{	
	CONFIGURE_FLAGS="--enable-pic --disable-cli --enable-strip $STATIC_DYLMIC"
	real_do_compile "$CONFIGURE_FLAGS" "x264"
}

#编译fdk-aac
do_compile_fdk_aac()
{
	local CONFIGURE_FLAGS="--with-pic $STATIC_DYLMIC"
	real_do_compile "$CONFIGURE_FLAGS" "fdk-aac"
}

#编译mp3lame
do_compile_mp3lame()
{
	#遇到问题：mp3lame连接时提示"export lame_init_old: symbol not defined"
	#分析原因：未找到这个函数的实现
	#解决方案：删除libmp3lame.sym中的lame_init_old
	SOURCE=./build/libsource/mp3lame/include/libmp3lame.sym
	$OUR_SED "/lame_init_old/d" $SOURCE
	
	CONFIGURE_FLAGS="--disable-frontend $STATIC_DYLMIC"
	real_do_compile "$CONFIGURE_FLAGS" "mp3lame"
}

#编译openssl
do_compile_ssl()
{
    local CONFIGURE_FLAGS="zlib-dynamic no-shared "
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        CONFIGURE_FLAGS="zlib-dynamic no-static-engine "
    fi
    
    real_do_compile "$CONFIGURE_FLAGS" "ssl" $1
}

#编译x265
do_compile_x265()
{   
    real_do_compile "$CONFIGURE_FLAGS" "x265"
}


# 编译外部库
compile_external_lib_ifneed()
{
    for (( i=$x264;i<${#LIBS[@]};i++ ))
    do
        lib=${LIBS[i]}
        FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib/lib
        
        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            if [[ ! -f "${FFMPEG_DEP_LIB}/lib$lib.a" && ! -f "${FFMPEG_DEP_LIB}/lib$lib.dll.a" && ! -f "${FFMPEG_DEP_LIB}/lib$lib.so" ]] ; then
                # 编译
                if [ $lib = "fdk-aac" ];then
                    lib=fdk_aac
                fi
                do_compile_$lib
            fi
        fi
    done;
}

do_compile_ffmpeg()
{
    if [ ${LIBFLAGS[$ffmpeg]} == "FALSE" ];then
        echo_r "config not build ffmpeg....return"
        return
    fi
    
	FF_BUILD_NAME=ffmpeg
	FF_BUILD_ROOT=`pwd`

	# 对于每一个库，他们的./configure 他们的配置参数以及关于交叉编译的配置参数可能不一样，具体参考它的./configure文件
	# 用于./configure 的参数
	FF_CFG_FLAGS=
	# 用于./configure 关于--extra-cflags 的参数，该参数包括如下内容：
	# 1、关于cpu的指令优化
	# 2、关于编译器指令有关参数优化
	# 3、指定引用三方库头文件路径或者系统库的路径
	FF_EXTRA_CFLAGS=""
	# 用于./configure 关于--extra-ldflags 的参数
	# 1、指定引用三方库的路径及库名称 比如-L<x264_path> -lx264
	FF_EXTRA_LDFLAGS=
	
	FF_SOURCE=$FF_BUILD_ROOT/build/libsource/$FF_BUILD_NAME
	FF_PREFIX=$FF_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$FF_BUILD_NAME
	mkdir -p $FF_PREFIX

	# 开始编译
	# 导入ffmpeg 的配置
	export COMMON_FF_CFG_FLAGS=
		. $FF_BUILD_ROOT/config/module.sh
	
    #硬编解码，不同平台配置参数不一样
    if [ $ENABLE_GPU = "TRUE" ] && [ $FF_PC_TARGET = "mac" ];then
        # 开启Mac/IOS的videotoolbox GPU编码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-encoder=h264_videotoolbox"
        # 开启Mac/IOS的videotoolbox GPU解码
        export COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS --enable-hwaccel=h264_videotoolbox"
    fi
    
	#导入ffmpeg的外部库，这里指定外部库的路径，配置参数则转移到了config/module.sh中
	EXT_ALL_LIBS=
    TYPE=a
    if [ $FF_COMPILE_SHARED = "TRUE" ];then
        TYPE=so
    fi
	#${#array[@]}获取数组长度用于循环
	for(( i=$x264;i<${#LIBS[@]};i++))
	do
		lib=${LIBS[i]};
		lib_inc_dir=$FF_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib/include
		lib_lib_dir=$FF_BUILD_ROOT/build/$FF_PC_TARGET-$FF_PC_ARCH/$lib/lib
        lib_pkg=${LIBS_PKGS[i]};
        if [[ ${LIBFLAGS[i]} == "TRUE" ]];then

            COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS ${LIBS_PARAM[i]}"

            FF_EXTRA_CFLAGS+=" $(pkg-config --cflags $lib_pkg)"
            FF_EXTRA_LDFLAGS+=" $(pkg-config --libs --static $lib_pkg)"
            
            EXT_ALL_LIBS="$EXT_ALL_LIBS $lib_lib_dir/lib*.$TYPE"
        fi
	done
	FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $FF_CFG_FLAGS"

    if [ $ENABLE_FFMPEG_TOOLS = "TRUE" ];then
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-ffmpeg --enable-ffplay --enable-ffprobe";
    fi
    
	# 开启调试;如果关闭 则注释即可
	#FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug --disable-optimizations";
	#--------------------
	
    if [[ $FF_PC_TARGET = "mac" ]];then
        # fixbug:mac osX 10.15.4 (19E266)和Version 11.4 (11E146)生成的库在调用libx264编码的avcodec_open2()函数
        # 时奔溃(报错stack_not_16_byte_aligned_error)，添加编译参数--disable-optimizations解决问题(fix：2020.5.2)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-optimizations";
    fi
    
	echo ""
	echo_c "--------------------"
	echo_c "[*] configurate ffmpeg"
	echo_c "--------------------"
	echo_p "FF_CFG_FLAGS=$FF_CFG_FLAGS"

	cd $FF_SOURCE
    set +e
    make distclean
    set -e
    ./configure $FF_CFG_FLAGS \
        --prefix=$FF_PREFIX \
        --extra-cflags="$FF_EXTRA_CFLAGS" \
        --extra-ldflags="$FF_EXTRA_LDFLAGS" \
        $STATIC_DYLMIC  \
    
	make && make install
	
    # 拷贝外部库
	for lib in $EXT_ALL_LIBS
	do
		cp -f $lib $FF_PREFIX/lib
	done
    
	cd -
}

useage()
{
    echo_c "Usage:"
    echo_p "  compile-ffmpeg-pc.sh mac|windows|linux"
    echo_p "  compile-ffmpeg-pc.sh mac|windows|linux clean-all|clean-*  (default clean ffmpeg,clean-x264 will clean x264)"
    exit 1
}

# 命令开始执行处----------
if [ "$FF_PC_TARGET" != "mac" ] && [ "$FF_PC_TARGET" != "windows" ] && [ "$FF_PC_TARGET" != "linux" ]; then
    useage
fi


#=== sh脚本执行开始 ==== #
# $FF_PC_ACTION 表示脚本执行时输入的第一个参数
case "$FF_PC_ACTION" in
    clean-*)
        # clean-all 清理所有当前平台的编译文件；clean-cache 清理源码缓存；clean-$lib 清理对应库的编译文件
        name=${FF_PC_ACTION#clean-*}
        rm_build $FF_PC_TARGET $name $FF_PC_ARCH
    ;;
    *)
        prepare_all $FF_PC_TARGET $FF_PC_ARCH
        
        rm -rf build/$FF_PC_TARGET-$FF_PC_ARCH/ffmpeg
        
        # 配置环境
        set_toolchain_path $FF_PC_ARCH
        
        # 先编译外部库
        compile_external_lib_ifneed
        
        # 最后编译ffmpeg
        do_compile_ffmpeg

        echo_g "Build Success!"
    ;;
esac
