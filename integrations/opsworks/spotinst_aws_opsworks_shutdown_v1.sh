#!/bin/bash
OPSWORKS_STACK_TYPE=""
OPSWORKS_STACK_ID=""
OPSWORKS_LAYER_ID=""
LOG_RECIPE='logging::run_script'
SLEEP_RECIPE='timesleeper::dosleep60'
if [ $OPSWORKS_STACK_TYPE == "CLASSIC" ]; then
    readonly OPSWORKS_ENDPOINT="us-east-1"
else
    readonly OPSWORKS_ENDPOINT=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}'`
fi

instanceOpsworksId=`aws opsworks --region $OPSWORKS_ENDPOINT describe-instances --stack-id $OPSWORKS_STACK_ID --output json | jq --arg hostname \`hostname\` '.Instances[] | select(.Hostname == $hostname)| .InstanceId' | awk -F '\"' {'print $2'}`

DEPLOY_ID=$(aws opsworks --region $OPSWORKS_ENDPOINT create-deployment --stack-id $OPSWORKS_STACK_ID \
    --instance-ids $instanceOpsworksId \
    --command "{\"Name\":\"execute_recipes\", \"Args\":{\"recipes\":[\"$LOG_RECIPE\",\"$SLEEP_RECIPE\"]}}" | jq '.DeploymentId' | tr -d '"')

sleep 600
 
instanceid=$( curl http://169.254.169.254/latest/meta-data/instance-id )
instance_signal=$( echo '{"instanceId" :  "'${instanceid}'",  "signal" : "INSTANCE_READY_TO_SHUTDOWN"}' )
echo $instance_signal > instance_signal
token="70a493f721747373800ff06c584ebc3c144473c04f78972ed87a3e2aeb97ca9c"
accountId="act-ea1affeb"
curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${token}" -d @instance_signal https://api.spotinst.io/aws/ec2/instance/signal?accountId=$accountId