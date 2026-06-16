# vLLM Semantic Router + OpenTelemetry Demo

> Route LLM requests by **intent, not by label** — then trace every routing
> decision end-to-end with OpenTelemetry and Coroot.

A self-contained Kubernetes demo that classifies each incoming prompt at the
gateway layer and rewrites `"model": "auto"` into the right specialist
(`math-expert`, `science-expert`, …) **before** it reaches the model — and
makes the whole decision observable, so you can see exactly where every
millisecond goes.

![Semantic Routing PoC overview](blog/images/sr.png)

Stack: [vLLM Semantic Router](https://vllm-semantic-router.com) ·
[agentgateway](https://agentgateway.dev) · Kubernetes (kind) ·
[OpenTelemetry](https://opentelemetry.io) · [Coroot](https://coroot.com)

📝 Full write-up (with diagrams): [`blog/semantic-routing-observability.md`](blog/semantic-routing-observability.md) ·
TL;DR: [`blog/SUMMARY.md`](blog/SUMMARY.md)

---

## What this demonstrates

Traditional gateways route on structure — URL path, headers, the `model` field
in the body. That only works when the caller already knows which model is best.
The **vLLM Semantic Router** runs as an Envoy External Processing (ExtProc)
service: it intercepts each request, classifies its *meaning* (domain
similarity + keyword rules), and rewrites the `model` field inline. Any
OpenAI-compatible client works unchanged.

Routing logic without observability is a black box. This demo wires
**OpenTelemetry → Coroot** so every routing decision becomes a trace:
`gateway frontend span → ExtProc → router spans`. You can finally answer
*"why was that AI response slow?"* — and the answer is often the routing, not
the model.

```
client ──HTTP──▶ agentgateway ──ExtProc──▶ semantic-router (classify + rewrite model)
   "auto"            │                              │
                     └──────────── traces ──────────┴──────▶ OTel Collector ──▶ Coroot
```

## Architecture at a glance

| Component | Role |
|-----------|------|
| **agentgateway** | Gateway API data plane; receives client traffic, emits a frontend span |
| **vLLM Semantic Router** | ExtProc server (`:50051`) that classifies intent and rewrites `model` |
| **vLLM simulator** | OpenAI-compatible backend serving a base model + 6 LoRA adapters (no GPU needed) |
| **OpenTelemetry Collector** | Trace sink; receives OTLP, forwards to Coroot |
| **Coroot** | Kubernetes-native observability UI; reads the traces |

## Prerequisites

```bash
kind version            # local Kubernetes cluster
kubectl version --client
helm version
jq --version            # used by the test/load scripts
```

You also need **agentgateway v1.3.0-alpha.1 or newer** — the ExtProc field the
router relies on landed after v1.2.1.

## Quick start

```bash
# 1. (optional) create a local cluster
kind create cluster

# 2. deploy the whole stack, in dependency order
./scripts/install.sh

# 3. port-forward the gateway (leave running in another terminal)
kubectl port-forward -n agentgateway-system svc/agentgateway-proxy 8080:80

# 4. prove routing works — math -> math-expert, science -> science-expert
./scripts/test.sh

# 5. generate traffic, then read the traces in Coroot
./scripts/load.sh
kubectl port-forward -n coroot svc/coroot 8880:8080
# open http://localhost:8880 -> Services -> semantic-router -> Tracing
```

Tear it all down with `./scripts/cleanup.sh` (add `--crds` to also remove the
Gateway API CRDs).

## Repository layout

```
.
├── README.md
├── blog/
│   ├── semantic-routing-observability.md   # the full blog post
│   ├── SUMMARY.md                          # short abstract / TL;DR
│   └── images/                             # diagrams + Coroot screenshots
├── values/
│   ├── otel-collector-values.yaml          # OTel Collector Helm values
│   ├── semantic-router-values.yaml         # full routing config (14 decisions)
│   └── agentgateway-values.yaml            # agentgateway Helm values
├── manifests/
│   ├── gateway.yaml                        # Gateway resource
│   ├── vllm-sim.yaml                       # vLLM backend simulator
│   ├── httproute-backend.yaml              # HTTPRoute + AgentgatewayBackend
│   ├── extproc-policy.yaml                 # attaches the router as ExtProc
│   └── tracing-policy.yaml                 # gateway-level frontend tracing
└── scripts/
    ├── install.sh                          # deploy everything, in order
    ├── test.sh                             # send two prompts, show routing
    ├── load.sh                             # batch of mixed-domain traffic
    └── cleanup.sh                          # tear it all down
```

## How it works (the short version)

1. **Observability first.** `install.sh` stands up Coroot and the OTel
   Collector *before* anything else — the router and gateway are configured to
   push traces at boot, so the sink has to exist or the first traces are lost.
2. **One base model, many experts.** The vLLM simulator serves a base model
   with six LoRA adapters. The router's job is to pick the right adapter from
   the prompt's meaning — no separate model deployments required.
3. **Routing at the gateway.** An `AgentgatewayPolicy` attaches the router as
   an ExtProc filter. The client sends `"model": "auto"`; the router rewrites
   it; vLLM receives the correct name. The client never knew.
4. **End-to-end traces.** A second `AgentgatewayPolicy` makes the gateway emit
   its own frontend span, so the trace in Coroot spans the *entire* request
   path, not just the routing decision.

## License

[MIT](LICENSE)

---

*Author: [Mohamed Aziz Ben Yahia](https://www.linkedin.com/in/mohamed-aziz-ben-yahia/)*
