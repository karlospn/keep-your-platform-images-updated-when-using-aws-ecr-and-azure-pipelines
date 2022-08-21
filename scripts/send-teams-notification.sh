#!/bin/bash
if [ -z "$1" ]; then
    echo "'aws_ecr_repository_name' parameter not found."
    exit 1
else
    aws_ecr_repository_name=$1
fi

if [ -z "$2" ]; then
    echo "'aws_tag_version' environment variable not found."
    exit 1
else
    aws_tag_version=$2
fi

if [ -z "$3" ]; then
    echo "'teams_webhook_uri' environment variable not found."
    exit 1
else
    teams_webhook_uri=$3
fi

echo "=========================================="
echo "Script parameters summary"
echo "aws_ecr_repository_name: $aws_ecr_repository_name"
echo "aws_tag_version: $aws_tag_version"
echo "teams_webhook_uri: $teams_webhook_uri"
echo "=========================================="

date_now=$(date +"%Y-%m-%d %T")
message='{"type":"message","attachments":[{"contentType":"application/vnd.microsoft.card.adaptive","content":{"type":"AdaptiveCard","body":[{"type":"TextBlock","size":"High","weight":"Bolder","text":"New platform image available."},{"type":"TextBlock","size":"Medium","weight":"Bolder","text":"A new platform image is **available** and **ready** to use."},{"type":"FactSet","facts":[{"title":"Image Name:","value":"'"$aws_ecr_repository_name"'"},{"title":"Version Tag:","value":"'"$aws_tag_version"'"},{"title":"Creation Time:","value":"'"$date_now"'"}]}],"$schema":"http://adaptivecards.io/schemas/adaptive-card.json","version":"1.0","msteams":{"width":"Full"}}}]}'

status_code=$(curl --write-out %{http_code} -k --silent --output /dev/null -H "Content-Type: application/json" -H "Accept: application/json" "${teams_webhook_uri}" -d "${message}")
echo $status_code

if [[ "$status_code" -ne 200 ]] ; then
    echo "Webhook post failed."
else
    echo "Webhook post succeed."
fi