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

echo "Check if private ECR Repository exists..."
output=$(aws ecr describe-repositories --repository-names $aws_ecr_repository_name 2>&1)

if [ $? -ne 0 ]; then
  if echo ${output} | grep -q RepositoryNotFoundException; then
    echo "ECR Repository not found"
    echo "Set environment variables to skip update check step"
    new_tag_version="$aws_ecr_tag_without_version-1.0.0"
    echo "Set environment variables tag version: $new_tag_version"
    echo "##vso[task.setvariable variable=aws_tag_version]$new_tag_version"
    echo "##vso[task.setvariable variable=skip_update_check]true"
    exit 0
  else
    echo "Error running the 'ecr describe-repositories' command"
    exit 1
  fi
fi

echo "Private ECR Repository found"
