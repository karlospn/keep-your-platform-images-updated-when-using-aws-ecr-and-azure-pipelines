# **Keep your dotnet platform images updated when using AWS ECR with Azure Pipelines**

## **Repository Content**

This repository contains an opinionated implementation of how to automate the creation and update of your dotnet platform images.

This implementation is built to work only with AWS Elastic Container Registry (AWS ECR) as the container registry and Azure Pipelines as orchestrator of the creation/update of the platform images.   
You could easily use another CI/CD tool, like GitHub Actions, but you need to do some minor tweaks on the scripts found in the `/shared/scripts` folder.

## **What's a platform image?**

When talking about containers security on the enterprise one of the best practices is to use your own platform images, those platform images will be the base for your company applications.

![platform-image-diagram](https://raw.githubusercontent.com/karlospn/keep-your-platform-images-updated-when-using-aws-ecr-and-azure-pipelines/main/docs/platform-images.png)

The point of having a platform image instead of directly using a base image is to ensure that the resulting containers are hardened according to any corporate policies before being deployed to production.     
Also if your enterprise applications need some kind of software baked into the images to run properly, it is far better to install it on the platform images, instead of having to install it in each and every one of the application images.

When working with .NET, there are quite a few official base images availables (https://hub.docker.com/_/microsoft-dotnet/), but we don't want to use those images directly on our enterprise applications, instead we want to use those official images from Microsoft as a base image to build a platform image that is going to be own by our company.    
The official Microsoft .NET images are not inherently bad and often include many security best practices, but a more secure way is to not rely solely on third party images, because you lose the ability to control scanning, patching, and hardening across your organization. The recommended way is using the official Microsoft images as the base for building everyone of your company platform images.

## **Create and update a .NET platform image**

Create a new platform image is an easy task, but you also want to keep the image up to date. 

Every time the base image gets a new update from Microsoft you'll want to update your platform image, because the latest version it's usually the most secure one.

The Microsoft image update policy for dotnet images is the following one:
- The .NET base images are updated within 12 hours of any updates to the underlying OS (e.g. debian:buster-slim, windows/nanoserver:ltsc2022, buildpack-deps:bionic-scm, etc.).
- When a new version of .NET (includes major/minor and servicing versions) gets released the dotnet base images gets updated.

The .NET base images might get updated quite frequently according to these policies, which means that automating the creation and update of our platform images is paramount, but automation is not the only important step, it is also important being able to manually update an existing platform image (maybe because we have installed a new piece of software on the platform image or updated some existing one or set some permissions).

## **Platform image creation/update process**

The following diagram contains the steps the pipeline executes to create or update a platform image.

The platform image creation/update process is going to be executed on an **Azure DevOps Pipeline**.   
Every platform image will have its own Azure DevOps pipeline.

![pipeline-diagram](https://raw.githubusercontent.com/karlospn/keep-your-platform-images-updated-when-using-aws-ecr-and-azure-pipelines/main/docs/update-platform-images-pipeline.png)

The pipeline uses a scheduled trigger because we need to periodically poll the Microsoft container registry (https://mcr.microsoft.com/) to check if there is any update available for the base image.   

When trying to update a platform image if there is NO new update available on the base image then the pipeline needs to end there.   
If there is a new updated base image on the Microsoft registry then the pipeline needs to create a new version of the platform image, test it, store it into ECR and notify that an update has ocurred via Teams channel.   
If you modify an existing platform image (for example, install some new software, update some existing one, set some permissions, etc) and want to create a new version of the platform image right away, you will be able to do it setting the ``force_update`` pipeline parameter to ``true``, that parameter will skip the Microsoft container registry update check and go straight into creating a new platform image.

## **Repository structure**

### **/platform-images folder**

The ``/platform-images`` folder will contain all your platform images, the platform images will be segregated by dotnet version (net5, net6, net7, etc).   

For any platform image you'll need:
- A ``Dockerfile`` which contains a set of instructions and commands that will be used to build the platform image.
- An ``azure-pipelines.yml`` pipeline that it will be used to create and update the corresponding platform image.    

This pipeline needs to use the ``/shared/templates/automatic-update-platform-image-template.yml`` YAML template. It also needs to define a schedule trigger that will be use to automatically check for updates (More info about in the "Platform image YAML Pipeline" section).

Right now the repository contains a couple of example of platform images.

- In the ``/platform-images/net6/sdk`` you'll find a platform image that uses the official Microsoft .NET6 SDK image as base image, It installs and setups the cred-provider (in case you need to restore NuGet packages from a private Azure DevOps feed).

- In the ``/platform-images/net6/runtime`` you'll find  a platform image that uses the official Microsoft .NET6 runtime image as base image. It sets a non-root user as its default user.
  
### **/shared folder**

This folder contains a set of scripts and assets used by the platform images pipelines.

- The ``/scripts`` folder contains a set of shell scripts used by the Azure Pipelines YAML template.
- The ``/templates`` folder contains an Azure Pipeline YAML template. This template is used by every platform images pipeline.
- The ``/integration-tests/{dotnet version}`` folder contains a real application that is going to be used as an integration test.

## **Integration Test pipeline step**

When updating a platform image we need to validate that the update doesn't break anything that could potentially affect our applications.   

The ``/shared/integration-tests`` folder will contain a series of applications that are going to be used as an integration test application. Every dotnet version will have its own integration test application.   
When building a new version of a platform image, we will test that the new image doesn't break anything by using the platform image as a base image on a real .NET application.

The integration test step runs the following commands: 

- Retrieves the test application from the ``/integration-tests/{dotnet version}``
- Overrides the ``FROM`` statement from the application ``Dockerfile`` with the current platform image we're building.
- Builds an image of the integration test app  and checks that the ``docker build`` process didn't thrown any warning or error.
- Starts the application using the ``docker run`` command.
- Sends an Http Request to the running application using cURL and expects that the response is a 200 OK status Code.

If all those steps run without any problem then the integration test is a success, if any of those steps fails then the integration test fails and breaks the pipeline.

## **Platform image YAML Pipeline**

- Every platform images needs an ``azure-pipeline.yml`` file.   
- The ``azure-pipelines.yml`` file needs to use the ``/shared/templates/automatic-update-platform-image-template.yml`` pipeline template. 
- It also needs a scheduled trigger that will be use to automatically check for updates on the base image.

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
- ``aws_ecr_tag_without_version``: The main tag we want to add to the platform image. The main tag will be automatically versioned by the pipeline.   
For example, let's say we set it to ``6.0-bullseye-slim``, if the platform image doesn't exist yet a tag named ``6.0-bullseye-slim-1.0.0`` will be added to the image , if the platform image already exists a tag named ``6.0-bullseye-slim-1.1.0`` will be added to the image, and so forth and so on in the following executions.
- ``aws_ecr_extra_tags``: Extra tags we want to add to this platform image, like the build ID, build Number, dotnet version, etc.
- ``mcr_registry_uri``: The URI of the Microsoft Registry that will be used to check if the base image contains a new update.   
For example, if the platform image is using the ``dotnet/runtime:6.0-bullseye-slim`` image as a base image, then the ``mcr_registry_uri`` has to be  ``https://mcr.microsoft.com/api/v1/catalog/dotnet/runtime/tags``.   
If the platform image is using the ``dotnet/runtime-deps:6.0-bullseye-slim`` image as a base image, then the ``mcr_registry_uri`` has to be ``https://mcr.microsoft.com/api/v1/catalog/dotnet/runtime-deps/tags``.
- ``mcr_tag_name``: The specific image tag from the Microsoft Registry that will be used to check if the base image contains a new update.   
For example, if the platform image is using the ``dotnet/runtime:6.0-bullseye-slim`` image as a base image, then the ``mcr_tag_name`` has to be  ``6.0-bullseye-slim``
- ``dockerfile_context_path``: The location of the platform image build context.
- ``integration_test_dockerfile_local_path``: The location of the integration test Dockerfile.
- ``integration_test_dockerfile_local_overwrite_image_name``: Which ``FROM`` statement needs to be overridden on the integration test app Dockerfile.
- ``integration_test_dockerfile_context``: The location of the integration test build context.
- ``teams_webhook_uri``: A Teams WebHook Uri. The pipeline notifies to a Teams Channel when a new platform image has been created or updated.
- ``force_update``: This parameter is used if you want to manually force the creation of a new version of the platform image. It skips the Microsoft container registry update check and goes straight into creating a new platform image.


