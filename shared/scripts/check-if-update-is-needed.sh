#!/bin/bash

if [ -z "$1" ]; then
    echo "'mcr_registry_uri' parameter not found."
    exit 1
else
    mcr_registry_uri=$1
fi

if [ -z "$2" ]; then
    echo "'mcr_tag_name' parameter not found."
    exit 1
else
    mcr_tag_name=$2
fi

if [ -z "$3" ]; then
    echo "'aws_ecr_repository_name' parameter not found."
    exit 1
else
    aws_ecr_repository_name=$3
fi

if [ -z "$4" ]; then
    echo "'aws_ecr_tag_without_version' parameter not found."
    exit 1
else
    aws_ecr_tag_without_version=$4
fi

echo "=========================================="
echo "Script parameters summary"
echo "mcr_registry_uri: $mcr_registry_uri"
echo "mcr_tag_name: $mcr_tag_name"
echo "aws_ecr_repository_name: $aws_ecr_repository_name"
echo "aws_ecr_tag_without_version: $aws_ecr_tag_without_version"
echo "=========================================="

http_response=$(curl -s -o response.txt -w "%{http_code}" $mcr_registry_uri)

if [ $http_response != "200" ]; then
   echo "Error retrieving container image information from Microsoft MCR Registry."
   exit 1
fi

body="$(cat response.txt)"

if [ -z "$body" ]; then
    echo "Container image information response from Microsoft MCR Registry came empty."
    exit 1
fi

mcr_push_date=$(jq --arg mcr_tag_name "$mcr_tag_name" '.[] | select(.name==$mcr_tag_name) | .lastModifiedDate' response.txt)

if [ -z "$mcr_push_date" ]; then
    echo "Container image information not found on Microsoft MCR Registry."
    exit 1
fi

mcr_push_date_cleaned=$(echo $mcr_push_date | tr -d '"' | cut -d "T" -f 1)
echo "Container with name: $mcr_tag_name was pushed last time on the MCR registry at: $mcr_push_date_cleaned"

aws_image=$(aws ecr describe-images --repository-name $aws_ecr_repository_name --image-ids imageTag=latest)

if [ -z "$aws_image" ]; then
    echo "Image $aws_ecr_repository_name not found on ECR."
    exit 1
fi

aws_image_pushed_at=$(echo $aws_image | jq -r '.imageDetails[0].imagePushedAt' | cut -d "T" -f 1)

if [ -z "$aws_image_pushed_at" ]; then
    echo "Image $aws_ecr_repository_name on ECR do not contain a imagePushedAt attribute."
    exit 1
fi

echo "Contaimer with name: $aws_ecr_repository_name was pushed on Vy ECR last time at: $aws_image_pushed_at"

if [[ "$aws_image_pushed_at" < "$mcr_push_date_cleaned" ]] ;
then
    echo "There are no new versions of the image in the MCR registry. Nothing further to do."
    echo "##vso[task.setvariable variable=skip_tasks]true"
    exit 0
fi

echo "Now checking image tags from the ECR image..."

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
