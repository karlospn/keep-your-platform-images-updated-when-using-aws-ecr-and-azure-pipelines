#!/bin/bash
if [ -z "$1" ]; then
    echo "'aws_ecr_repository_name' parameter not found."
    exit 1
else
    aws_ecr_repository_name=$1
fi

if [ -z "$2" ]; then
    echo "'integration_test_dockerfile_local_path' parameter not found."
    exit 1
else
    integration_test_dockerfile_local_path=$2
fi

if [ -z "$3" ]; then
    echo "'integration_test_dockerfile_local_overwrite_image_name' parameter not found."
    exit 1
else
    integration_test_dockerfile_local_overwrite_image_name=$3
fi

if [ -z "$4" ]; then
    echo "'integration_test_dockerfile_context' parameter not found."
    exit 1
else
    integration_test_dockerfile_context=$4
fi

echo "=========================================="
echo "Script parameters summary"
echo "aws_ecr_repository_name: $aws_ecr_repository_name"
echo "integration_test_dockerfile_local_path: $integration_test_dockerfile_local_path"
echo "integration_test_dockerfile_local_overwrite_image_name: $integration_test_dockerfile_local_overwrite_image_name"
echo "integration_test_dockerfile_context: $integration_test_dockerfile_context"
echo "=========================================="

export DOCKER_BUILDKIT=1

if [[ -f "$integration_test_dockerfile_local_path" ]]; then
    echo "$integration_test_dockerfile_local_path exists."
else
    echo "$integration_test_dockerfile_local_path file does not exist"
    exit 1
fi

echo "Replacing content on Dockerfile..."
sed -i "/$integration_test_dockerfile_local_overwrite_image_name/c\FROM platform.image:tmp" $integration_test_dockerfile_local_path

echo "Output dockerfile content"
cat $integration_test_dockerfile_local_path

echo "Building image..."
docker build -t testapp:latest --progress=plain  -f $integration_test_dockerfile_local_path $integration_test_dockerfile_context 2>&1 | tee build.log

echo "Analyze docker build log output..."
grep -q "warning" build.log; [ $? -eq 0 ] && echo "warnings found on the docker build log" && exit 1
echo "No errors or warnings found on docker build log output"

echo "Run image..."
container_id=$(docker run -d -p 5055:8080 testapp:latest)
sleep 20

echo "Print docker logs..."
docker logs $container_id

echo "Run integration test..."
status_code=$(curl -X 'POST' --write-out %{http_code} -k --silent --output /dev/null 'http://localhost:5055/MyService' -H 'accept: application/json' -H 'Content-Type: application/json-patch+json' -d '{ "data": "string", "color": "Red"}')
echo $status_code

if [[ "$status_code" -ne 200 ]] ; then
    echo "Integration Test failed."
    exit 1
else
    echo "Integration Test succeeded."
fi