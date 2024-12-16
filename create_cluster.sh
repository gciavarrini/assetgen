#!/bin/bash

# Define the cluster configuration using
# instructions in https://github.com/cloudfoundry/korifi/blob/v0.13.0/INSTALL.kind.md
cat <<EOF | kind create cluster --name korifi --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localregistry-docker-registry.default.svc.cluster.local:30050"]
        endpoint = ["http://127.0.0.1:30050"]
    [plugins."io.containerd.grpc.v1.cri".registry.configs]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."127.0.0.1:30050".tls]
        insecure_skip_verify = true
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 32080
    hostPort: 80
    protocol: TCP
  - containerPort: 32443
    hostPort: 443
    protocol: TCP
  - containerPort: 30050
    hostPort: 30050
    protocol: TCP
EOF

# Wait for the Kind cluster to be ready
echo
echo "⏳ Waiting for the Kind cluster to be ready..."
until kubectl cluster-info --context kind-korifi &>/dev/null; do
  echo "Cluster not yet ready, retrying in 5 seconds..."
  sleep 5
done
echo "✅ Cluster is ready!"


# Wait for all pods in all namespaces to be ready
echo
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=ready --timeout=600s pods --all --all-namespaces


# Wait for all deployments in all namespaces to be ready
echo
echo "⏳ Waiting for all deployments to become ready..."
kubectl wait --for=condition=available --timeout=600s deployments --all --all-namespaces

echo
echo "✅ Korifi installation complete and all pods and deployments are ready!"
