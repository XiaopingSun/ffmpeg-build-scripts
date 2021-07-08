#! /usr/bin/env bash

# ======= 检查编译环境 ========= #
uname=`uname`
echo_g "check $uname build env......"
if [[ $uname = "Darwin" ]]  && [[ ! `which brew` ]]; then
    # Mac平台检查是否安装了 brew；如果没有安装，则进行安装
    echo_g "check Homebrew env......"
	echo_r 'Homebrew not found. Trying to install...'
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
    echo_g "check Homebrew ok......"
fi

# 检查是否安装了pkg-config;linux和windows才需要安装pkg-config
echo_g "check pkg-config env......"
if [[ $uname = "Darwin" && $FF_PLATFORM_TARGET != "mac" ]] && [ ! `which pkg-config` ]; then
    echo_r "pkg-config not found begin install....."
    apt-cyg install pkg-config || exit 1
    echo_g "check pkg-config ok......"
fi

# 检查是否安装了cmake
echo_g "check cmake env......"
if [[ $uname = "Darwin" ]] && [[ ! `which cmake` ]]; then
    echo_r "cmake not found begin install....."
    brew install cmake || exit 1
    echo_g "check cmake ok......"
fi

# # wget用于下载资源的命令包
# echo "check wget env......"
# if [[ ! `which wget` ]]; then
#     echo "wget not found begin install....."
#     if [[ "$(uname)" == "Darwin" ]];then
#         # Mac平台;自带
#         brew install wget
#     elif [[ "$(uname)" == "Linux" ]];then
#         # Linux平台
#         sudo apt install wget || exit 1
#     else
#         # windows平台
#         apt-cyg install wget || exit 1
#     fi
# fi
# echo -e "check wget ok......"

# yasm是PC平台的汇编器(nasm也是，不过yasm是nasm的升级版)，用于windows，linux，osx系统的ffmpeg汇编部分编译；
if [[ ! `which yasm` ]] && [[ $FF_PLATFORM_TARGET != "ios" && $FF_PLATFORM_TARGET != "android" ]]; then
    echo_g "check yasm env......"
	echo_r "yasm not found begin install....."
	if [[ "$(uname)" == "Darwin" ]];then
        # Mac平台
        brew install yasm || exit 1
    elif [[ "$(uname)" == "Linux" ]];then
        # Linux平台和windows平台
        wget http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz || exit 1
        tar zxvf yasm-1.3.0.tar.gz || exit 1
        rm yasm-1.3.0.tar.gz
        cd yasm-1.3.0
        ./configure || exit 1
		sudo make && sudo make install || exit 1
        cd -
        rm -rf yasm-1.3.0
    else
        # windows平台
        apt-cyg install yasm || exit 1
    fi
    echo_g "check yasm ok......"
fi

if [[ ! `which autoconf` ]]; then
    # autotools工具集，autoconf用于基于GNU的make生成工具，有些库不支持Libtool;
    echo_g "check autoconf env......"
    echo_r "autoconf not found begin install....."
    
    
    if [[ "$(uname)" == "Darwin" ]];then
        # Mac平台
        brew install autoconf automake pkg-config || exit 1
    elif [[ "$(uname)" == "Linux" ]];then
        # Linux平台平台
        sudo apt-get install -y pkg-config autoconf automake autotools-dev libtool libev-dev
        #result=$(echo `autoconf --version`)
        #if [[ "$result" < "1.16.1" ]];then
        #    sudo apt-get --purge remove automake
        #    wget http://ftp.gnu.org/gnu/automake/automake-1.16.1.tar.gz
        #    tar zxvf automake-1.16.1.tar.gz || exit 1
        #   rm automake-1.16.1.tar.gz
        #   cd automake-1.16.1
        #    ./configure || exit 1
        #    sudo make && sudo make install || exit 1
        #   cd -
        #    rm -rf automake-1.16.1
        #fi
    else
        # windows平台
        apt-cyg install autoconf || exit 1
    fi
    echo_g "check autoconfl ok......"
fi

if [[ $uname = "Darwin" && $FF_PLATFORM_TARGET == "ios" ]]  && [[ ! `which gas-preprocessor.pl` ]]; then
    # gas-preprocessor.pl是IOS平台用的汇编器，安卓则包含在ndk目录中，不需要单独再指定
    echo_g "check gas-preprocessor.pl env......"
	echo_r "gas-preprocessor.pl not found begin install....."
    git clone https://github.com/libav/gas-preprocessor
    sudo cp gas-preprocessor/gas-preprocessor.pl /usr/local/bin/gas-preprocessor.pl
    chmod +x /usr/local/bin/gas-preprocessor.pl
	rm -rf gas-preprocessor
    echo_g "check gas-preprocessor.pl ok......"
fi

# 遇到问题：cygwin平台编译fdk-aac时提示" 'aclocal-1.15' is missing on your system."
# 分析原因：未安装automake
# 解决方案：安装automake
if [[ "$uname" = CYGWIN_NT-* ]]  && [[ ! `which automake` ]]; then
    echo_g "check automake env......"
    echo_r "automake not found begin install....."
    apt-cyg install automake || exit 1
    echo_g "check automake ok......"
fi

# 如果要编译ffplay则还需要编译SDL2库
if [[ $ENABLE_FFMPEG_TOOLS = "TRUE" ]] && [[ $FF_PLATFORM_TARGET != "ios" && $FF_PLATFORM_TARGET != "android" ]]; then
    echo_g "check SDL2 env......"
    if [[ $uname = "Darwin" ]] && [[ ! -d /usr/local/Cellar/sdl2 ]]; then
        brew install SDL2 || exit 1
    elif [[ $uname = "Linux" ]] && [[ ! `dpkg -l|grep libsdl` ]];then
        sudo apt-get install libsdl2-2.0
        sudo apt-get install libsdl2-dev
    fi
    echo_g "check SDL2 env ok......"
fi
