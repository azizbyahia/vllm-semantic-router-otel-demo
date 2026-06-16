#!/usr/bin/env bash
#
# Tears down everything install.sh created. Leaves the Gateway API CRDs in
# place (they are cluster-wide and harmless); pass --crds to remove them too.
#
# Usage: ./scripts/cleanup.sh [--crds]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.5.0}"

echo "==> Removing routing wiring + tracing policies"
kubectl delete -f "${REPO_ROOT}/manifests/tracing-policy.yaml" --ignore-not-found
kubectl delete -f "${REPO_ROOT}/manifests/extproc-policy.yaml" --ignore-not-found
kubectl delete -f "${REPO_ROOT}/manifests/httproute-backend.yaml" --ignore-not-found

echo "==> Uninstalling Helm releases"
helm uninstall semantic-router -n agentgateway-system --ignore-not-found || true
kubectl delete -f "${REPO_ROOT}/manifests/vllm-sim.yaml" --ignore-not-found
kubectl delete -f "${REPO_ROOT}/manifests/gateway.yaml" --ignore-not-found
helm uninstall agentgateway -n agentgateway-system --ignore-not-found || true
helm uninstall agentgateway-crds -n agentgateway-system --ignore-not-found || true
helm uninstall otel-collector --ignore-not-found || true
helm uninstall coroot -n coroot --ignore-not-found || true
helm uninstall coroot-operator -n coroot --ignore-not-found || true

if [[ "${1:-}" == "--crds" ]]; then
  echo "==> Removing Gateway API CRDs"
  kubectl delete -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml" --ignore-not-found
fi

echo "Done."
