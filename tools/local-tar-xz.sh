#! /usr/bin/env bash

LOCAL_WORKSPACE=$1
TAR_TARGET=$2


if [ -z $LOCAL_WORKSPACE -o -z $TAR_TARGET ]; then
    echo_r "invalid param '$LOCAL_WORKSPACE' '$TAR_TARGET'"
    exit 1
fi

# 目录已经存在 则先删除
if [ -d $LOCAL_WORKSPACE/$TAR_TARGET ]; then
    rm -rf $LOCAL_WORKSPACE/$TAR_TARGET
fi

# 解压指定的.tar.xz文件
echo_c "== tar $TAR_TARGET xz =="
cd $LOCAL_WORKSPACE
mkdir -p $TAR_TARGET
tar -xvJf $TAR_TARGET.tar.xz --strip-components 1 -C $TAR_TARGET
cd -
echo_c "tar $TAR_TARGET xz success"
