#!/bin/bash

set -e

# Docker repository to use. Default to docker hub.
REPONAME=joshuarobinson

# Build docker image.
docker build -t ior .

# Push to docker repository.
docker tag ior $REPONAME/ior
docker push $REPONAME/ior
