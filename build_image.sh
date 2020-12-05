#!/bin/bash

set -e

# Docker repository to use. Default to docker hub.
REPONAME=joshuarobinson
TAG=io500

# Build docker image.
docker build -t $TAG .

# Push to docker repository.
docker tag $TAG $REPONAME/$TAG
docker push $REPONAME/$TAG
