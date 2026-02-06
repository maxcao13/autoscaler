#!/bin/bash

# Copyright The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Installs KWOK (Kubernetes WithOut Kubelet) into the current cluster.
# Creates a fake KWOK node for benchmark pods to be scheduled on.
#
# Prerequisites: kubectl
#
# Usage: ./install-kwok.sh

set -euo pipefail

KWOK_VERSION="${KWOK_VERSION:-v0.7.0}"
KWOK_NAMESPACE="${KWOK_NAMESPACE:-kube-system}"
KWOK_NODE_NAME="${KWOK_NODE_NAME:-kwok-node}"

echo "=== Installing KWOK ${KWOK_VERSION} ==="

# Check if KWOK is already installed
if kubectl get deployment kwok-controller -n "${KWOK_NAMESPACE}" &>/dev/null; then
  echo "  KWOK already installed, skipping"
else
  echo "  Applying KWOK manifests..."
  kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}/kwok.yaml"

  echo "  Applying KWOK stage-fast manifests..."
  kubectl apply -f "https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}/stage-fast.yaml"

  echo "  Waiting for KWOK controller to be ready..."
  kubectl wait --for=condition=Available deployment/kwok-controller -n "${KWOK_NAMESPACE}" --timeout=60s
fi

# Create fake KWOK node
if kubectl get node "${KWOK_NODE_NAME}" &>/dev/null; then
  echo "  KWOK node '${KWOK_NODE_NAME}' already exists, skipping"
else
  echo "  Creating KWOK fake node '${KWOK_NODE_NAME}'..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Node
metadata:
  name: ${KWOK_NODE_NAME}
  annotations:
    node.alpha.kubernetes.io/ttl: "0"
    kwok.x-k8s.io/node: fake
    node.kubernetes.io/exclude-from-external-load-balancers: "true"
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: ${KWOK_NODE_NAME}
    kubernetes.io/os: linux
    kubernetes.io/role: agent
    node-role.kubernetes.io/agent: ""
    type: kwok
spec:
  taints:
    - key: kwok.x-k8s.io/node
      value: fake
      effect: NoSchedule
EOF
  echo "  Created KWOK fake node"
fi

echo "=== KWOK installation complete ==="
