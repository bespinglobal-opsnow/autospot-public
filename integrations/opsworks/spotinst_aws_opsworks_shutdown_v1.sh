#!/bin/bash
# Elastigroup Scale Down 시 OpsWorks에서 실앻되는 OpsWorks Agent Uninstaller를 제거하여 OpsWorks Log 삭제를 방지.
sudo rm -rf /opt/aws/opsworks/current/bin/opsworks-agent-uninstaller
# Shutdown Script에 필요한 OPSWORKS STACK TYPE, STACK ID, LAYER ID 값을 설정
# CLASSIC 또는 REGIONAL
OPSWORKS_STACK_TYPE=""
# OPSWORKS STACK ID
OPSWORKS_STACK_ID=""
# OPSWORKS LAYER ID
OPSWORKS_LAYER_ID=""

# SHUTDOWN 시 실행해야할 RECIPE들 정의.
# 예시
## LOG_RECIPE='logging::run_script'
## SLEEP_RECIPE='timesleeper::dosleep60'
LOG_RECIPE=''
SLEEP_RECIPE=''

# STACK TYPE에 따른 OPSWORKS API ENDPOINT 분기처리
if [ $OPSWORKS_STACK_TYPE == "CLASSIC" ]; then
    readonly OPSWORKS_ENDPOINT="us-east-1"
else
    readonly OPSWORKS_ENDPOINT=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}'`
fi

# OPSWORKS 내 인스턴스별 UUID 조회
instanceOpsworksId=`aws opsworks --region $OPSWORKS_ENDPOINT describe-instances --stack-id $OPSWORKS_STACK_ID --output json | jq --arg hostname \`hostname\` '.Instances[] | select(.Hostname == $hostname)| .InstanceId' | awk -F '\"' {'print $2'}`

# RECIPE를 실행하는 Deploy 코드
DEPLOY_ID=$(aws opsworks --region $OPSWORKS_ENDPOINT create-deployment --stack-id $OPSWORKS_STACK_ID \
    --instance-ids $instanceOpsworksId \
    --command "{\"Name\":\"execute_recipes\", \"Args\":{\"recipes\":[\"$LOG_RECIPE\",\"$SLEEP_RECIPE\"]}}" | jq '.DeploymentId' | tr -d '"')

# Deploy 이후 10분간 Sleep
sleep 600
 
# Elastigroup에 인스턴스를 종료해도 된다는 Signal을 보내는 API 호출부.
instanceid=$( curl http://169.254.169.254/latest/meta-data/instance-id )
instance_signal=$( echo '{"instanceId" :  "'${instanceid}'",  "signal" : "INSTANCE_READY_TO_SHUTDOWN"}' )
echo $instance_signal > instance_signal
token=""
accountId=""
curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${token}" -d @instance_signal https://api.spotinst.io/aws/ec2/instance/signal?accountId=$accountId