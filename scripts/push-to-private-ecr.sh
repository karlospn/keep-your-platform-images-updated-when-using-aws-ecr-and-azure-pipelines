#!/bin/bash
if [ -z "$1" ]; then
    echo "'aws_account' parameter not found."
    exit 1
else
    aws_account=$1
fi

if [ -z "$2" ]; then
    echo "'aws_region' parameter not found."
    exit 1
else
    aws_region=$2
fi

if [ -z "$3" ]; then
    echo "'aws_ecr_repository_name' parameter not found."
    exit 1
else
    aws_ecr_repository_name=$3
fi

if [ -z "$4" ]; then
    echo "'aws_tag_version' environment variable not found."
    exit 1
else
    aws_tag_version=$4
fi

if [ -z "$5" ]; then
    echo "'aws_extra_tags' parameter not found."
    exit 1
else
    aws_extra_tags=$5
fi

echo "=========================================="
echo "Script parameters summary"
echo "aws_account: $aws_account"
echo "aws_region: $aws_region"
echo "aws_ecr_repository_name: $aws_ecr_repository_name"
echo "aws_tag_version: $aws_tag_version"
echo "aws_extra_tags: $aws_extra_tags" 
echo "=========================================="

aws ecr get-login-password --region $aws_region | docker login --username AWS --password-stdin $aws_account.dkr.ecr.$aws_region.amazonaws.com
aws ecr create-repository --repository-name $aws_ecr_repository_name --region $aws_region --image-scanning-configuration scanOnPush=true
docker tag platform.image:tmp $aws_account.dkr.ecr.$aws_region.amazonaws.com/$aws_ecr_repository_name:$aws_tag_version
docker tag platform.image:tmp $aws_account.dkr.ecr.$aws_region.amazonaws.com/$aws_ecr_repository_name:latest
docker push $aws_account.dkr.ecr.$aws_region.amazonaws.com/$aws_ecr_repository_name:$aws_tag_version
docker push $aws_account.dkr.ecr.$aws_region.amazonaws.com/$aws_ecr_repository_name:latest

array_tags=( $aws_extra_tags )
for extra_tag in "${array_tags[@]}"
do
    docker tag platform.image:tmp $aws_account.dkr.ecr.$aws_region.amazonaws.com/$aws_ecr_repository_name:$extra_tag
    docker push $aws_account.dkr.ecr.$aws_region.amazonaws.com/$aws_ecr_repository_name:$extra_tag
done