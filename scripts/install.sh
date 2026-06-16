#!/usr/bin/env bash
#
# Deploys the full demo stack on the current kubectl context, in order:
#   1. Coroot (observability backend)        2. OpenTelemetry Collector
#   3. agentgateway                          4. Gateway resource
#   5. vLLM simulator                        6. vLLM Semantic Router
#   7. Routing wiring (HTTPRoute + ExtProc)  8. Gateway-level tracing
#
# The observability backend goes first on purpose: the router and gateway
# are configured to push traces to the collector at boot, so the collector
# must already exist or those first traces are lost.
#
# Usage: ./scripts/install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTGATEWAY_VERSION="${AGENTGATEWAY_VERSION:-v1.3.0-alpha.1}"
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.5.0}"

echo "==> 1/8  Installing Coroot"
helm repo add coroot https://coroot.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade -i coroot-operator coroot/coroot-operator -n coroot --create-namespace
helm upgrade -i coroot coroot/coroot-ce -n coroot \
  --set "clickhouse.shards=2,clickhouse.replicas=2"

echo "==> 2/8  Installing OpenTelemetry Collector"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade -i otel-collector open-telemetry/opentelemetry-collector \
  --values "${REPO_ROOT}/values/otel-collector-values.yaml"

echo "==> 3/8  Installing Gateway API CRDs + agentgateway"
kubectl apply --server-side --force-conflicts \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
helm upgrade -i agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --create-namespace --namespace agentgateway-system \
  --version "${AGENTGATEWAY_VERSION}"
helm upgrade -i agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --namespace agentgateway-system \
  --version "${AGENTGATEWAY_VERSION}" \
  --values "${REPO_ROOT}/values/agentgateway-values.yaml" \
  --wait

echo "==> 4/8  Creating the Gateway resource"
kubectl apply -f "${REPO_ROOT}/manifests/gateway.yaml"

echo "==> 5/8  Deploying the vLLM backend simulator"
kubectl apply -f "${REPO_ROOT}/manifests/vllm-sim.yaml"
kubectl wait --for=condition=Available deployment/vllm-llama3-8b-instruct \
  -n default --timeout=300s

echo "==> 6/8  Installing the vLLM Semantic Router"
helm upgrade -i semantic-router \
  oci://ghcr.io/vllm-project/semantic-router/charts/semantic-router \
  --namespace agentgateway-system --create-namespace \
  --values "${REPO_ROOT}/values/semantic-router-values.yaml"

echo "==> 7/8  Wiring routing (HTTPRoute + ExtProc policy)"
kubectl apply -f "${REPO_ROOT}/manifests/httproute-backend.yaml"
kubectl apply -f "${REPO_ROOT}/manifests/extproc-policy.yaml"

echo "==> 8/8  Enabling gateway-level tracing"
kubectl apply -f "${REPO_ROOT}/manifests/tracing-policy.yaml"

cat <<'DONE'

Done. The stack is up and wired to push traces into Coroot.

Next:
  ./scripts/test.sh        # send a math + science prompt with model: "auto"
  ./scripts/load.sh        # generate a batch of traffic for the traces

Open the dashboards:
  kubectl port-forward -n coroot svc/coroot 8880:8080
  # then http://localhost:8880  ->  Services -> semantic-router -> Tracing
DONE
