#!/bin/bash

if [ -z "$1" ]; then
    echo "'aws_ecr_repository_name' parameter not found."
    exit 1
else
    aws_ecr_repository_name=$1
fi

if [ -z "$2" ]; then
    echo "'aws_ecr_tag_without_version' parameter not found."
    exit 1
else
    aws_ecr_tag_without_version=$2
fi

echo "=========================================="
echo "Script parameters summary"
echo "aws_ecr_repository_name: $aws_ecr_repository_name"
echo "aws_ecr_tag_without_version: $aws_ecr_tag_without_version"
echo "=========================================="

aws_image=$(aws ecr describe-images --repository-name $aws_ecr_repository_name --image-ids imageTag=latest)

echo "Checking image tags from the ECR image..."

for row  in $(echo $aws_image | jq -r '.imageDetails[0].imageTags'); do   
    sub=$aws_ecr_tag_without_version
    if [[ "$row" == *"$sub"* ]]; then
        aws_image_tag=$row
        break
    fi
done

if [ -z "$aws_image_tag" ]; then
    echo "Tag was not found on the ECR image."
    exit 1
fi

echo "Image tag found: $aws_image_tag"
echo "Now calculating new image tag..."

version=$(echo $aws_image_tag | sed 's/.*-//')
if [ -z "$version" ]; then
    echo "Tag version was not found on the ECR image."
    exit 1
fi

major=$(echo $version |  tr -d '"' | cut -d '.' -f 1)
if [ -z "$major" ]; then
    echo "Tag major version was not found on the ECR image."
    exit 1
fi

minor=$(echo $version |  tr -d '"' | cut -d '.' -f 2)
if [ -z "$minor" ]; then
    echo "Tag minor version was not found on the ECR image."
    exit 1
fi

patch=$(echo $version |  tr -d '"' | tr -d ',' | cut -d '.' -f 3)
if [ -z "$patch" ]; then
    echo "Tag patch version was not found on the ECR image."
    exit 1
fi

update_minor=$(($minor+1))
new_tag_version="$aws_ecr_tag_without_version-$major.$update_minor.0"

echo "New image tag is: $new_tag_version"
echo "Now setting this as a pipeline environment variable."
echo "##vso[task.setvariable variable=aws_tag_version]$new_tag_version"
