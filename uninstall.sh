#!/bin/bash

kind delete cluster --name kind
docker network disconnect -f kind client 2>/dev/null || true
docker rm -f $(docker ps -a -q --filter label=io.x-k8s.kind.cluster=kind) 2>/dev/null || true
docker network rm kind 2>/dev/null || true
