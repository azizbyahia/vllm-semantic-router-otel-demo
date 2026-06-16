# TL;DR — Semantic Routing Under the Microscope

**The one-liner:** route LLM requests by *meaning* instead of by a hard-coded
model name, and trace every routing decision so latency can't hide.

## The problem

In a multi-model setup — a general model, a math LoRA, a code model, a private
on-prem model — forcing every client to know which one to call is fragile.
Send an FAQ to a frontier model and you overpay; send a proof to a 3B model and
it hallucinates. Worse, when responses are slow, you can't tell whether the
*model* or the *routing decision* is to blame.

## The approach

- **Semantic routing.** The vLLM Semantic Router classifies each prompt
  (domain-embedding similarity + keyword rules), then a priority-based decision
  engine picks a destination — a LoRA adapter, a different model, or a cached
  response.
- **Routing at the gateway, not in the app.** The router runs as an Envoy
  ExtProc service behind agentgateway. The client sends `"model": "auto"`; the
  router rewrites it inline before it reaches vLLM. Any OpenAI-compatible
  client works unchanged.
- **Observability built in from the start.** OpenTelemetry exports a trace for
  every decision to a collector that forwards to Coroot. A gateway-level
  tracing policy adds a frontend span, producing one continuous timeline:
  `gateway → ExtProc → router`.

## What you can see

Open Coroot and each request is a span hierarchy: how long signal extraction
takes, embedding similarity vs. rule-based classification, whether routing
latency is stable under load, and where the bottleneck actually is.

## The takeaway

Semantic routing makes multi-model AI architectures practical by moving the
"which model?" decision into the infrastructure. Adding OpenTelemetry + Coroot
turns that decision from a black box into something you can measure — and the
next time someone asks "why is my AI response slow?", the answer might surprise
you: it was the routing, not the model.

> **Stack:** vLLM Semantic Router · agentgateway · Kubernetes (kind) ·
> OpenTelemetry · Coroot

📖 Read the full post: [`semantic-routing-observability.md`](semantic-routing-observability.md)
