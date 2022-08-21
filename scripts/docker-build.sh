#!/bin/bash
if [ -z "$1" ]; then
    echo "'image_context' parameter not found."
    exit 1
else
    image_context=$1
fi

echo "=========================================="
echo "Script parameters summary"
echo "image_context: $image_context"
echo "=========================================="

docker build -t platform.image:tmp $image_context