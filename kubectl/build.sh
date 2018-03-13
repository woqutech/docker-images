#!/bin/bash
# kubectl docker image for Linux x86-64
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
docker build -t kubectl .
