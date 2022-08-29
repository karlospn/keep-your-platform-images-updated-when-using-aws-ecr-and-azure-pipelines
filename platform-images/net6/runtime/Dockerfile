FROM mcr.microsoft.com/dotnet/runtime:6.0-bullseye-slim

# Set non-root user
RUN groupadd -r devsecops && useradd -r --uid 1000 -g devsecops devsecops \
    && mkdir /app \
    && mkdir /home/devsecops \
    && chown -R devsecops /app \
    && chown -R devsecops /home/devsecops

# Set the default user
USER devsecops

# Non-user root cannot start on port 80
ENV ASPNETCORE_URLS=http://+:8080