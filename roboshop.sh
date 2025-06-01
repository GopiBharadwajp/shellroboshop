#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-03a031274602046a1"
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z0095891220EQ8FJXWFW1"
DOMAINNAME="gorobo.site"

if [ $# -gt 0 ]; then
  instances=("$@")
else
  instances=("${INSTANCES[@]}")
fi

for instance in "${instances[@]}"
do
    echo "Creating instance for: $instance"

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t3.micro \
        --security-group-ids "$SG_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
        --query "Instances[0].InstanceId" \
        --output text)

    echo "Launched instance ID: $INSTANCE_ID"
    
    # Wait for instance to be in running state
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query "Reservations[0].Instances[0].PrivateIpAddress" \
            --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text)
        RECORD_NAME="${instance}.${DOMAIN_NAME}"

    fi

    echo "$instance IP address: $IP"

    # Create JSON payload dynamically
    CHANGE_BATCH=$(cat <<EOF
{
    "Comment": "Creating or Updating a record set for $instance",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$RECORD_NAME",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$IP"
                    }
                ]
            }
        }
    ]
}
EOF
)

   


   aws route53 change-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --change-batch "$CHANGE_BATCH"
done



