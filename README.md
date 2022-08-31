# **Keep your dotnet platform images updated when using AWS ECR with Azure Pipelines**

## **Repository Content**

This repository contains an opinionated implementation of how to automate the creation and update of your dotnet platform images.

This implementation is built to work only with AWS Elastic Container Registry (AWS ECR) as the container registry and Azure Pipelines as orchestrator of the creation/update of the platform images.   
You could easily use another CI/CD tool, like GitHub Actions, but you need to do some minor tweaks on the scripts found in the `/shared/scripts` folder.

## **What's a platform image?**

When talking about containers security on the enterprise one of the best practices is to use your own platform images, those platform images will be the base for your company applications.

![platform-image-diagram](https://raw.githubusercontent.com/karlospn/keep-your-platform-images-updated-when-using-aws-ecr-and-azure-pipelines/main/docs/platform-images.png)

The point of having and using a platform image instead of a base image is to ensure that the resulting containers are hardened according to any corporate policies before being deployed to production.

For dotnet there are a few official docker images avalaible on the Microsoft registry (https://hub.docker.com/_/microsoft-dotnet/), but we don't want to use those images directly on our enterprise applications. Instead of that we are going to use those official images from Microsft as a base image to build a platform image that is going to be own by our company.

## **Create and update a dotnet platform image**

Create a platform image is easy enough, but you'll want to keep it up to date. Everytime the base image gets a new update from Microsoft you'll want to update your platform image.

The Microsoft image update policy for dotnet image is the following one:
- The .NET base images are updated within 12 hours of any updates to the underlying OS (e.g. debian:buster-slim, windows/nanoserver:ltsc2022, buildpack-deps:bionic-scm, etc.).
- When a new version of .NET (includes major/minor and servicing versions) gets released the dotnet base images get updated.

The .NET base images might get updates on a regular basis and we want that our platform images always use the most up to date version available, that's the reason why automating the creation and update of our platform image is paramount.

Also everytime you change something on an existing platform image (install some new software, update some existing one, set some permissions, etc) you will want to create a new version of the platform image right away.

## **Platform image creation/update process**

The following diagram contains the steps the pipeline executes to create or update a platform image.

![pipeline-diagram](https://raw.githubusercontent.com/karlospn/keep-your-platform-images-updated-when-using-aws-ecr-and-azure-pipelines/main/docs/update-platform-images-pipeline.png)

The pipeline gets triggered on a scheduled basis (every Monday at 6:00 UTC), it uses a scheduled trigger because we want to periodically poll the Microsoft container registry (https://mcr.microsoft.com/) to check if there is any update available for the base image.

When trying to update an image if there is NO new update available on the base image then the pipeline just ends there.   
If there is a new updated base image on the Microsoft registry then the pipeline will create a new version of the platform image, test it, store it into ECR and notify the update into a Teams Channel.

Also if you want to change something on an existing platform image (install some new software, update some existing one, set some permissions, etc) you will want to create a new version of the platform image right away, you can do it setting the ``force_update`` pipeline parameter to ``true``, that parameter will skip the Microsoft container registry update check and go straight into creating a new platform image.

## **Repository structure**

### **/platform-images folder**

The ``/platform-images/{dotnet version}`` folder will contain all your platform images, the platform images are segregated by dotnet version (dotnet5, dotnet6, dotnet7, etc).   

Foreach platform image you'll have:
- A ``Dockerfile`` which contains a set of instructions and commands that will be used to create/build the platform image.
- An ``azure-pipelines.yml`` pipeline, it will be use to create/update the corresponding platform image.   
This pipeline needs to use the ``/shared/templates/automatic-update-platform-image-template.yml`` YAML template. It also needs to define a schedule trigger that will be use to automatically check for updates (More info about in the "Platform image YAML Pipeline" section).

Right now the repository contains a couple of example of platform images.

- In the ``/platform-images/net6/sdk`` you'll find a platform image that uses the .NET6 SDK platform image as base image and also installs and setups the cred-provider (in case you need to restore NuGet packages from a private Azure DevOps feed).

- In the ``/platform-images/net6/runtime`` you'll find  a platform image that uses the .NET6 runtime image as base image and sets a non-root user as its default user.
  
### **/shared folder**

This folder contains a set of shared scripts and assets used by the platform image pipeline.

- The ``/scripts`` folder contains a set of shell scripts used by the Azure Pipelines YAML template.
- The ``/templates`` folder contains an Azure Pipeline YAML template. This template is used by every platform images pipeline.
- The ``/integration-tests/{dotnet version}`` folder contains an application that is going to be used as an integration test. More info about it, in the next section.

## **Integration Test**

When updating a platform image we need to validate that the update doesn't break anything that could potentially affect our applications.   
The pipeline contains a step that validates that you can run the new platform image in a real application without any unexpected error.

The ``/integration-tests/{dotnet version}`` folder contains an application that is going to be used as an integration test application. Every dotnet version should have its own integration test application, that's the reason why the ``integration-tests`` folder contains multiple subfolders.

The validation process runs the following steps: 

- Retrieves the test application from the ``/integration-tests/{dotnet version}``
- Overrides the ``FROM`` statement from the integration test ``Dockerfile`` with the platform image we're building.
- Checks that the ``docker build`` process didn't thrown any warning or error.
- Starts the application using the ``docker run`` command.
- Sends an Http Request to the running application using cURL and expects that the response is a 200 OK status Code.

If all those steps run without any problem then the integration test is a success, if any of those steps fails the integration test fails and breaks the pipeline.

## **Platform image YAML Pipeline**

Every platform images need an ``azure-pipeline.yml`` .   
The ``azure-pipelines.yml`` file needs to use the ``/shared/templates/automatic-update-platform-image-template.yml`` pipeline template. It also needs a scheduled trigger that will be use to automatically check for updates on the base image.

Here's an example of how an ``azure-pipeline.yml`` file will look like:

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
- ``aws_account``: AWS Account Number.
- ``private_ecr_region``: AWS Region
- ``aws_ecr_repository_name``: Name of the ECR repository where the image is going to be stored.
- ``aws_ecr_tag_without_version``: The main tag we want to add to this platform image. The main tag will be automatically versioned by the pipeline.   
Here's an example, let's say we set it to ``6.0-bullseye-slim``, if the platform image doesn't exist yet a tag named ``6.0-bullseye-slim-1.0.0`` will be added to the image , if the platform image already exists a tag named ``6.0-bullseye-slim-1.1.0`` will be added to the image, and so forth and so on in the following executions.
- ``aws_ecr_extra_tags``: Extra tags we want to add to this platform image, like the build Id, build Number, dotnet version, etc.
- ``mcr_registry_uri``: The URI of the Microsoft Registry which we will be used to check if the base image contains a new update.   
Here's an example, if the platform image is using the ``dotnet/runtime:6.0-bullseye-slim`` image as a base image, then the ``mcr_registry_uri`` has to be  ``https://mcr.microsoft.com/api/v1/catalog/dotnet/runtime/tags``.   
If the platform image is using the ``dotnet/runtime-deps:6.0-bullseye-slim`` image as a base image, then the ``mcr_registry_uri`` has to be ``https://mcr.microsoft.com/api/v1/catalog/dotnet/runtime-deps/tags``.
- ``mcr_tag_name``: The specific image tag from the Microsoft Registry which we will used to search if the base image contains a new update.   
Here's an example, if the platform image is using the ``dotnet/runtime:6.0-bullseye-slim`` image as a base image, then the ``mcr_tag_name`` has to be  ``6.0-bullseye-slim``
- ``dockerfile_context_path``: The location of the platform image build context.
- ``integration_test_dockerfile_local_path``: The location of the integration test dockerfile.
- ``integration_test_dockerfile_local_overwrite_image_name``: Which ``FROM`` statement needs to be overridden on the integration test Dockerfile.
- ``integration_test_dockerfile_context``: The location of the integration test build context.
- ``teams_webhook_uri``: A Teams WebHook Uri. The pipelines notifies to a Teams Channel when a new platform image has been created or updated.
- ``force_update``: If you want to create a new version of the platform image right away, you can do it setting this parameter to ``true`` and it will skip the Microsoft container registry update check and go straight into creating a new platform image.


