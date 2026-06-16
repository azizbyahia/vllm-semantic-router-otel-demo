#!/usr/bin/env bash
#
# Sends two prompts with model: "auto" and prints the model each one was
# routed to. A math prompt should come back as "math-expert" and a science
# prompt as "science-expert" — proof the router classified and rewrote the
# request without the client ever naming a model.
#
# Usage: ./scripts/test.sh
set -euo pipefail

GATEWAY="${GATEWAY:-http://localhost:8080}"

if ! curl -sf -o /dev/null "${GATEWAY}/v1/models" 2>/dev/null; then
  echo "Gateway not reachable at ${GATEWAY}."
  echo "Port-forward it first, in another terminal:"
  echo "  kubectl port-forward -n agentgateway-system svc/agentgateway-proxy 8080:80"
  exit 1
fi

ask() {
  local label="$1" prompt="$2"
  local routed
  routed=$(curl -s "${GATEWAY}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"auto\", \"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}]}" \
    | jq -r '.model')
  printf '  %-9s "%s"\n            -> routed to: %s\n' "${label}" "${prompt}" "${routed}"
}

echo "Sending prompts with model: \"auto\" ..."
ask "math:"    "What is the derivative of x squared?"
ask "science:" "How does mitosis work?"
