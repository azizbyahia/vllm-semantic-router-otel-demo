#!/usr/bin/env bash
#
# Fires a batch of mixed-domain prompts at the gateway to generate trace
# data, then points you at Coroot to read it.
#
# Usage: ./scripts/load.sh
set -euo pipefail

GATEWAY="${GATEWAY:-http://localhost:8080}"

prompts=(
  "solve the equation 2x + 5 = 15"
  "what is the speed of light"
  "write a Python function to reverse a string"
  "explain the theory of relativity"
  "what is the capital of Japan"
  "integrate cos(x) from 0 to pi"
)

echo "Sending ${#prompts[@]} requests to ${GATEWAY} ..."
for prompt in "${prompts[@]}"; do
  curl -s "${GATEWAY}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"auto\", \"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}]}" \
    >/dev/null &
done
wait

echo "Done. Open Coroot to read the traces:"
echo "  kubectl port-forward -n coroot svc/coroot 8880:8080"
echo "  http://localhost:8880  ->  Services -> semantic-router -> Tracing"
