# **Keep your dotnet platform images updated when using AWS ECR with Azure Pipelines**

**This repository is still a work in progress**

## **What's a platform image?**

When talking about containers security on the enterprise one of the best practices is to use your own platform images, those platform images will be the base for your company applications.

![platform-image-diagram](https://raw.githubusercontent.com/karlospn/keep-your-platform-images-updated-when-using-aws-ecr-and-azure-pipelines/main/docs/platform-images.png)

The point of having and using a platform image instead of a base image is to ensure that the resulting containers are hardened according to any corporate policies before being deployed to production.

For dotnet there are a few official docker images avalaible on the Microsoft registry (https://hub.docker.com/_/microsoft-dotnet/), but we don't want to use those images directly on our enterprise applications. Instead of that we are going to use those official images from Microsft to build a platform image that is going to be own by our company.

## **How to create and update a dotnet platform image**

Create a platform image is easy enough, but you'll want to keep it up to date. Everytime the base image gets a new update from Microsoft you'll want to update your platform image.

The Microsoft image update policy for dotnet image is the following one:
- The .NET base images are updated within 12 hours of any updates to their base images (e.g. debian:buster-slim, windows/nanoserver:ltsc2022, buildpack-deps:bionic-scm, etc.).
- When a new version of .NET (including major/minor and servicing versions) gets released the .NET base images get updated.

The .NET base images might get updates on a regular basis and we want that our platform images always use the most up to date version available, that's the reason why automating the creation and update of our platform image is paramount.

## **Platform image creation/update process**

The following diagram contains the steps the pipeline executes to create or update a platform image.

![pipeline-diagram](https://raw.githubusercontent.com/karlospn/keep-your-platform-images-updated-when-using-aws-ecr-and-azure-pipelines/main/docs/update-platform-images-pipeline.png)

The pipeline gets triggered on a scheduled basic (every Monday at 6:00 UTC), it uses a scheduled trigger because we want to periodically poll the Microsoft container registry (https://mcr.microsoft.com/) to check if there is an update on any of the base image we're using on our platform images.

## **Repository Content**

This repository contains a series of scripts and templates that will allow you to automate the creation and update of you dotnet platform images.

The scripts are built to use AWS Elastic Container Registry (AWS ECR) as the container registry and Azure Pipelines as orchestrator of the creation/update of the platform images (you could easily use another CI/CD tool, like GitHub Actions, but you need to do some minor tweaks on the scripts found in the `/shared/scripts` folder).

## **Repository structure**

### **platform-images folder**

The ``/platform-images/{dotnet version}`` folder will contain all your platform images, the platform images are segregated for by dotnet version.   

Foreach platform image you'll need:
- A ``Dockerfile`` which contains a set of instructions and commands that will be used to create/build the platform image.
- An ``azure-pipelines.yml`` pipeline, it will be use to create/update a platform image. This pipeline needs to use the ``/shared/templates/automatic-update-platform-image-template.yml`` pipeline template. It also needs to define a schedule trigger that will be use to automatically check for updates.


The repository contains a couple of example of platform images.

- In the ``/platform-images/net6/runtime`` you'll find  a platform image that uses the .NET6 runtime image as base image.
  
- In the ``/platform-images/net6/sdk`` you'll find a ``Dockerfile`` used to create a platform image that uses the .NET6 SDK platform image as base image.


### **shared folder**

This folder contains a set of shared scripts and assets used in the platform image pipeline.

- The ``/scripts`` folder contains a set of shell scripts used by the Azure Pipelines YAML template.
- The ``/templates`` folder contains an Azure Pipeline YAML template. This template is used by the platform images pipelines.
- The ``/integration-tests/{dotnet version}`` folder contains an application that is going to be used as an integration test. More info about it, in the next section.

## **Integration Test**

When updating a platform image we need to validate that the new update does not contain a breaking change that could potentially affect our applications.

The ``/integration-tests/{dotnet version}`` folder contains an application that is going to be used as an integration test application.    

The pipeline will create a image using this application and the new platform image we're building to test if there is any unexpected error.

## **Platform image YAML Pipeline**

The ``/platform-images/{dotnet version}`` folder will contain all your platform images, the platform images are segregated for by dotnet version.   

Foreach platform image you'll need:
- A ``Dockerfile`` which contains a set of instructions and commands that will be used to create/build the platform image.
- An ``azure-pipelines.yml`` pipeline that it will be used to create/update a platform image. 

The ``azure-pipelines.yml`` file needs to use the ``/shared/templates/automatic-update-platform-image-template.yml`` pipeline template. It also needs a scheduled trigger that will be use to automatically check for updates on the base image.

Here's an example of how the ``azure-pipeline.yml`` will look like:

```yaml
trigger: none

schedules:
- cron: "0 6 * * 1"
  displayName: Run At 06:00 UTC every Monday
  branches:
    include:
    - main

parameters:
- name: force_update
  type: boolean
  default: false

pool:
  vmImage: ubuntu-latest

extends:
  template: ../../../shared/templates/automatic-update-platform-image-template.yml
  parameters:
      aws_credentials: 'aws-dev'
      aws_account: '934045942927'
      private_ecr_region: 'eu-west-1'
      aws_ecr_repository_name: 'runtime' 
      aws_ecr_tag_without_version: '6.0-bullseye-slim' 
      aws_ecr_extra_tags:
      - 6.0
      - $(Build.BuildNumber)
      mcr_registry_uri: 'https://mcr.microsoft.com/api/v1/catalog/dotnet/runtime/tags' 
      mcr_tag_name: '6.0-bullseye-slim' 
      dockerfile_context_path: '$(System.DefaultWorkingDirectory)/platform-images/net6/runtime' 
      integration_test_dockerfile_local_path: '$(System.DefaultWorkingDirectory)/shared/integration-tests/net6/Dockerfile' 
      integration_test_dockerfile_local_overwrite_image_name: 'runtime:6.0-bullseye-slim' 
      integration_test_dockerfile_context: '$(System.DefaultWorkingDirectory)/shared/integration-tests/net6' 
      teams_webhook_uri: '$(TEAMS_WEBHOOK_URI)'
      force_update: ${{ parameters.force_update }}
```

The ``automatic-update-platform-image-template`` YAML template needs the following parameters:
- ``aws_credentials``: An Azure DevOps Service Connection to AWS.
- ``aws_account``: AWS Account Number where the platform image are going to be stored.
- ``private_ecr_region``: AWS Region
- ``aws_ecr_repository_name``: Name of the ECR repository where the image is going to be stored.
- ``aws_ecr_tag_without_version``: The main tag we want to add to this platform image. This main tag will be automatically versioned by the pipeline.   
Here's an example, let's say we set the value to ``6.0-bullseye-slim``, if the platform image doesn't exist yet the image will contain a tag named ``6.0-bullseye-slim-1.0.0`` , if the platform image already exists and a new update from the base image is available it will add a tag named ``6.0-bullseye-slim-1.1.0``, and so forth and so on. 
- ``aws_ecr_extra_tags``: Extra tags we want to add to this platform image, like the buildID, buildNumber or dotnet version.
- ``mcr_registry_uri``: The URI of the Microsoft Registry which we will use to check if the base image contains a new update. For example, if the platform image is using the ``dotnet/runtime:6.0-bullseye`` image as a base image the ``mcr_registry_uri`` will be  ``https://mcr.microsoft.com/api/v1/catalog/dotnet/runtime/tags``
- ``mcr_tag_name``: The specific image tag from the Microsoft Registry which we will use to check if the base image contains a new update. For example, if the platform image is using the ``dotnet/runtime:6.0-bullseye`` image as a base image the ``mcr_tag_name`` will be  ``6.0-bullseye``
- ``dockerfile_context_path``: The location of the platform image build context.
- ``integration_test_dockerfile_local_path``: The location of the integration test dockerfile.
- ``integration_test_dockerfile_local_overwrite_image_name``: Which ``FROM`` statement needs to be overriden on the integration test Dockerfile.
- ``integration_test_dockerfile_context``: The location of the integration test build context.
- ``teams_webhook_uri``: Teams WebHook Uri. The pipelines notifies to a Teams Channel that a new platform image has been created or updated.
- ``force_update``: It forces to create a new version of the platform image.


