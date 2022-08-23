FROM mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim
WORKDIR /app

# Copy everything and restore packages
COPY . ./
RUN dotnet restore -s "https://api.nuget.org/v3/index.json" \
	--runtime linux-x64	

# Build project
RUN dotnet build "./IntegrationTest.WebApi.csproj" \ 
    -c Release \
	--runtime linux-x64 \
	--no-restore


# Publish app
RUN dotnet publish "./IntegrationTest.WebApi.csproj" \
	-c Release \
	-o /app/publish \
	--no-restore \ 
	--no-build \
	--runtime linux-x64

# Build runtime image
FROM mcr.microsoft.com/dotnet/runtime:6.0-bullseye-slim

# Expose port
EXPOSE 8080

# Copy artifact with execution rights
WORKDIR /app
COPY --chmod=0755 --from=0 /app/publish .

# Set Entrypoint
ENTRYPOINT ["dotnet", "IntegrationTest.WebApi.dll"]
