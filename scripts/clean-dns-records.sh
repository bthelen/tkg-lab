#!/bin/bash -e

TKG_LAB_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $TKG_LAB_SCRIPTS/set-env.sh

DNS_PROVIDER=$(yq r $PARAMS_YAML dns.provider)

if [ "$DNS_PROVIDER" = "gcloud-dns" ];
then
  # Using Google Cloud DNS
  echo "Using Google Cloud DNS -- TODO make this work!"
  exit 1
else
  # Default is to use AWS Route53
  echo "Using AWS Route53"
  AWS_HOSTED_ZONE_ID=$(yq r $PARAMS_YAML aws.hosted-zone-id)
  if [ -z "$AWS_HOSTED_ZONE_ID" ];then
    echo "AWS hosted zone id not found in configuration file.  Bail out because I can't clean it."
    exit 1
  else
    echo "AWS Hosted Zone Id found in configuration, go clean out records."
    export AWS_REGION=$(yq r $PARAMS_YAML aws.region)
    export AWS_ACCESS_KEY_ID=$(yq r $PARAMS_YAML aws.access-key-id)
    export AWS_SECRET_ACCESS_KEY=$(yq r $PARAMS_YAML aws.secret-access-key)
    # first remove all the A records that should be dangling
    for i in $(aws route53 list-resource-record-sets --hosted-zone-id $AWS_HOSTED_ZONE_ID --query "ResourceRecordSets[?Type == 'A']" | jq '.[].Name'); do
      # strip the double quotes
      i=$(echo $i | sed s/\"//g)
      echo "Fetching JSON of resource" $i
      RESOURCE_TO_DELETE=$(aws route53 list-resource-record-sets --hosted-zone-id $AWS_HOSTED_ZONE_ID --query "ResourceRecordSets[?Name == '${i/\\\\/\\}' && Type == 'A']" | jq '.[0]')

      RESOURCE_DELETION_JSON="
        {
          \"Comment\": \"DELETE A record that should no longer be used\",
          \"Changes\": [
            {
              \"Action\": \"DELETE\",
              \"ResourceRecordSet\": $RESOURCE_TO_DELETE
            }
          ]
        }"
        aws route53 change-resource-record-sets --hosted-zone-id $AWS_HOSTED_ZONE_ID --change-batch "$RESOURCE_DELETION_JSON"
    done

    # next remove all the TXT records that should be dangling
    for i in $(aws route53 list-resource-record-sets --hosted-zone-id $AWS_HOSTED_ZONE_ID --query "ResourceRecordSets[?Type == 'TXT']" | jq '.[].Name'); do
      # strip the double quotes
      i=$(echo $i | sed s/\"//g)
      echo "Fetching JSON of resource" $i
      RESOURCE_TO_DELETE=$(aws route53 list-resource-record-sets --hosted-zone-id $AWS_HOSTED_ZONE_ID --query "ResourceRecordSets[?Name == '${i/\\\\/\\}' && Type == 'TXT']" | jq '.[0]')

      RESOURCE_DELETION_JSON="
        {
          \"Comment\": \"DELETE TXT record that should no longer be used\",
          \"Changes\": [
            {
              \"Action\": \"DELETE\",
              \"ResourceRecordSet\": $RESOURCE_TO_DELETE
            }
          ]
        }"
        aws route53 change-resource-record-sets --hosted-zone-id $AWS_HOSTED_ZONE_ID --change-batch "$RESOURCE_DELETION_JSON"
    done

  fi
fi
