#!/bin/sh

# WARNING: 脚本拷贝torrent文件的目标地址在下载文件的路径下，所以如果有开启监视文件夹功能，请禁止递归子目录，否则_Torrent文件夹内拷贝到的torrent文件会被再次监视。



# echo "args num: $#, all args: $@" > /vol1/@appshare/qBittorrent/test.log

# torrent_name=$1 #%N
# torrent_category=$2 #%L
# torrent_tag=$3 #%G
# torrent_savepath=$4 #%D
# torrent_hashcode=$5 #%I

# 此脚本是通过在torrent的文件下载保存路径下创建一个名为_Torrent的文件夹，
# 然后把torrent文件复制到该文件夹下，从而实现自动管理torrent文件

# 此脚本需要配合qBittorrent的分类和标签配置

# 必须参数
# -n torrent名，用来命名拷贝的torrent文件，因为BT_backup目录下torrent文件命名格式为torrent的hashcode
# -l torrent分类，此参数需要配合qBittorrent的分类功能使用，分类名必须按照“PT站名/分类名”定义，脚本会通过获取此参数首个斜线前的值来区分PT站，并选择对应的文件名前缀，如，[gamegamept.com].、[Rousi].等
# -g torrent标签，此参数暂时没有用到
# -d 文件下载后的保存路径，会通过此路径拼接torrent文件拷贝到的目标地址
# -i torrent的hash码，用来到BT_backup目录下寻找对应的torrent文件

# 定义日志文件
log_file="./copy_torrent.log"

# 创建日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $@"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $@" >> "$log_file"
}

logE() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') Error: $@" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') Error: $@" >&2 >> "$log_file"
}

log "-------------------------------------------Start running script...-----------------------------------------------"

# BT_backup目录
bt_backup="/vol1/@appcenter/qBittorrent/qBittorrent_conf/data/BT_backup"
# 在torrent_savepath路径下创建用来拷贝torrent文件的文件夹名称，也就是目标文件夹
torrent_dir_name="_Torrents"

# 扩充新的必须参数时，记得检测参数的合法性
while getopts ":n:l:g:f:r:d:c:z:t:i:j:k:" opt;
do
    case $opt in
        n)
            torrent_name=$OPTARG
            ;;
        l)
            torrent_category=$OPTARG
            ;;
        g)
            torrent_tag=$OPTARG
            ;;
        f)
            ;;
        r)
            ;;
        d)
            torrent_savepath=$OPTARG
            ;;
        c)
            ;;
        z)
            ;;
        t)
            ;;
        i)
            torrent_hashcode=$OPTARG
            ;;
        j)
            ;;
        k)
            ;;
        :)
            logE "-${OPTARG} requires an argument."
            ;;
        \?)
            log "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        
        # *)
        #     echo "Usage:  [-t_name] [-t_category] [-t_tag] [-t_savepath] [-t_hascode]"
        #     exit 1
        #     ;;
        
    esac
done

# 检测参数的合法性 begin [ADD]

if [ -z "$torrent_name" ]; then
    logE "Torrent name (-n) is required"
    exit 1
fi

if [ -z "$torrent_category" ]; then
    logE "Torrent category (-l) is required"
    exit 1
fi

# if [ -z "$torrent_tag" ]; then
#     logE "Torrent tag (-g) is required"
#     exit 1
# fi

if [ -z "$torrent_savepath" ]; then
    logE "Torrent savepath (-d) is required"
    exit 1
fi

if [ -z "$torrent_hashcode" ]; then
    logE "Torrent hashcode (-i) is required"
    exit 1
fi

# 检测参数的合法性 end

log "torrent_name: $torrent_name, torrent_category: $torrent_category, torrent_tag: $torrent_tag, torrent_savepath: $torrent_savepath, torrent_hashcode: $torrent_hashcode"

validate_path() {
    local path="$1"

    log "======== Checking path: $path ========"
    
    # 检查路径是否为空
    if [ -z "$path" ]; then
        logE "Path is empty"
        return 1
    fi
    
    # 检查路径是否绝对路径（可选）
    if [ "${path#/}" = "$path" ]; then
        logE "Path must be absolute"
        return 1
    fi
    
    # 检查路径是否存在
    if [ ! -d "$path" ]; then
        logE "Directory $path does not exist"
        return 1
    fi
    
    # 检查路径是否可写
    if [ ! -w "$path" ]; then
        logE "Directory $path is not writable"
        return 1
    fi
    
    log "======== Check passed: $path ========"

    return 0
}

# 使用验证函数
if ! validate_path "$torrent_savepath"; then
    logE "Torrent savepath (-d) is invalid path: $torrent_savepath"
    exit 1
fi

#记录拷贝的目标路径
torrent_target_path="$torrent_savepath/$torrent_dir_name"

# 判断torrent_savepath路径下是否存在Torrent文件夹，若不存在自动创建
if [ ! -d "$torrent_target_path" ]; then
    mkdir -p "$torrent_target_path"
    if [ $? -eq 0 ]; then
        log "Created Torrent directory successfully"
    else
        logE "Failed to create Torrent directory"
        exit 1
    fi
fi

# 检测BT_backup路径是否有效
if ! validate_path "$bt_backup"; then
    logE "BT_backup path is invalid: $bt_backup"
    exit 1
fi

# 检测以hashcode为名的种子文件是否存在
if [ ! -f "$bt_backup/$torrent_hashcode.torrent" ]; then
    logE "Not Found torrent file["$torrent_hashcode.torrent"] in BT_backup directory"
    exit 1
fi

# 截取 torrent_category 首个斜线前的字符串
torrent_platform=${torrent_category%%/*}
torrent_name_prefix=""

log "++++++++ platform: $torrent_platform ++++++++"

# 通过不同的PT站点，添加其站点的种子文件前缀，没有前缀规则的可忽略 [ADD]
if [ "$torrent_platform" = "PT_GGPT" ]; then
    torrent_name_prefix="[gamegamept.com]."
elif [ "$torrent_platform" = "PT_Rousi" ]; then
    torrent_name_prefix="[Rousi]."
fi

# 检测是否有同名种子文件
if [ -f "$torrent_target_path/$torrent_name_prefix$torrent_name.torrent" ]; then
    logE "[$torrent_target_path/$torrent_name_prefix$torrent_name.torrent] already exists, please copy manually."
    exit 1
fi

log "Starting copy torrent file..."
log "torrent_hashcode: $torrent_hashcode"
log "torrent_name: $torrent_name"
log "From: $bt_backup"
log "To: $torrent_target_path"

cp -f "$bt_backup/$torrent_hashcode.torrent" "$torrent_target_path/$torrent_name_prefix$torrent_name.torrent"

log "Copy torrent file completed"

