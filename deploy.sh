#!/bin/bash
# 执行JAR
EXEC_JAR=${EXEC_JAR}
APP_PORT=${APP_PORT}
# APP 启动参数 11
SPRINT_BOOT_PROFILE=$SPRINT_BOOT_PROFILE
# JAVA 启动参数
JAVA_JAR_OPTIONS=$JAVA_JAR_OPTIONS
# 应用的启动日志
APP_START_LOG=$(dirname ${EXEC_JAR})/logs/start.log
# 应用健康检查URL
#HEALTH_CHECK_URL=http://127.0.0.1:${APP_PORT}${HEALTH_CHECK_URI}
HEALTH_CHECK_URL=http://127.0.0.1:${APP_PORT}

# 脚本会在这个目录下生成nginx-status文件
HEALTH_CHECK_FILE_DIR=$(dirname ${EXEC_JAR})/status
# 部署命令
APP_START_TIMEOUT=30    # 等待应用启动的时间

PROG_NAME=$0
ACTION=$1

# 创建出相关目录
mkdir -p $(dirname ${EXEC_JAR})/logs
mkdir -p ${HEALTH_CHECK_FILE_DIR}

usage() {
    echo "Usage: $PROG_NAME {start|stop|restart}"
    exit 2
}

health_check() {
    expTime=0
    echo "checking ${HEALTH_CHECK_URL}"
    while true
        do
            status_code=`/usr/bin/curl -L -o /dev/null --connect-timeout 5 -s -w %{http_code}  ${HEALTH_CHECK_URL}`
            if [ "$?" != "0" ]; then
               echo -n -e "\r application not started"
            else
                echo "code is $status_code"
                if [ "$status_code" == "200" ];then
                    break
                fi
            fi
            sleep 1
            ((expTime++))

            echo -e "\r Wait app to pass health check: expTime..."

            if [ expTime -gt ${APP_START_TIMEOUT} ]; then
                echo 'app start failed'
               exit 1
            fi
        done
    echo "check ${HEALTH_CHECK_URL} success"
}

start_application() {
    echo "java process starting...  启动命名: nohup java -jar ${SPRINT_BOOT_PROFILE} ${EXEC_JAR}  > ${APP_START_LOG} 2>&1 &"
    nohup java -jar ${JAVA_JAR_OPTIONS} ${SPRINT_BOOT_PROFILE} ${EXEC_JAR}  > ${APP_START_LOG} 2>&1 &
    echo "java process started"
}

stop_application() {
  checkjavapid=`ps -ef | grep java | grep ${EXEC_JAR} | grep -v grep |grep -v '${DEPLOY_SH_EXE}' | awk '{print$2}'`

     if [[ ! $checkjavapid ]];then
        echo -e "\rno java process"
        return
     fi

     echo "stop java process"
     times=60
     for e in $(seq 60)
     do
          sleep 1
          COSTTIME=$(($times - $e ))
          checkjavapid=`ps -ef | grep java | grep ${EXEC_JAR} | grep -v grep |grep -v '${DEPLOY_SH_EXE}' | awk '{print$2}'`
          if [[ $checkjavapid ]];then
              kill -9 $checkjavapid
              echo -e  "\r        -- stopping java lasts `expr $COSTTIME` seconds."
          else
              echo -e "\rjava process has exited"
              break;
          fi
     done
     echo ""
}

start() {
    start_application
    health_check
}

stop() {
    stop_application
}

case "$ACTION" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        stop
        start
    ;;
    *)
        usage
    ;;
esac
