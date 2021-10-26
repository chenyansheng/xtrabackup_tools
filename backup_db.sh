#! /bin/bash
# @doc 基于xtrabackup工具做的mysql备份
#   只备份默认自带库 + 指定库
#   如果crontab执行，需要确保有添加环境变量
# @author chenyansheng
# @date 2021-10-26
ROOT=`cd $(dirname $0)/..; pwd`
BACKUP_DIR=/data/backup/db
DB_USER=root  # mysql用户
DB_PASS=root  # mysql密码
# 当前时间
NOW=`date +'%Y%m%d-%H%M'`
BACKUP_LOG="${BACKUP_DIR}/${NOW}.log"


error() {
    echo $1 | tee -a ${BACKUP_LOG}
    echo "$1" | mail -s backup_db_problem randychen@outlook.com
    exit 1
}

echo2() {
    echo $1 | tee -a ${BACKUP_LOG}
}

# 检测db是否存在
check_db_exist() {
    db=$1
    check=`mysql -u${DB_USER} -p${DB_PASS} -e "show databases;" | grep "^${db}$"`
    if [[ -n "$check" ]]; then
        return 0
    fi
    return 1
}

# 最少备份db
BACKUP_DB_LIST="information_schema mysql performance_schema test"
# 指定需要备份的库
DB_FOR_BACKUP="test1 test2 test3"

BACKUP_DB_LIST="${BACKUP_DB_LIST} ${DB_FOR_BACKUP}"


# 备份前先刷新binlog(给自己留一条后路)
echo2 "刷新binlog"
if !( mysql -u${DB_USER} -p${DB_PASS} -e "flush logs;" ); then
    error "刷新binlog失败"
fi

# 备份
echo2 "开始备份：${BACKUP_DB_LIST}"
if !(/usr/local/xtrabackup/bin/innobackupex --user ${DB_USER} --password ${DB_PASS} --databases "${BACKUP_DB_LIST}" ${BACKUP_DIR} >> ${BACKUP_LOG} 2>&1 ); then
    error "backup ${BACKUP_DB_LIST} fail"
fi

# 删除过旧的备份文件（30天前）
if [[ -d ${BACKUP_DIR} ]]; then
    cd ${BACKUP_DIR}
    find ./ -name "*-*-*_*-*-*" -ctime +30 -type d -exec rm -rf {} \;
    find ./ -name "*-*.log" -ctime +30 -type f -exec rm -rf {} \;
fi
