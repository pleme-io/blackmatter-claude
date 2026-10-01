# engenho as a qualification substrate

### engenho as a qualification substrate — consumers' needs are its backlog

A local engenho cluster is used to qualify manifests bound for upstream
Kubernetes. When a qualification needs something engenho does not do, engenho
gains the capability: measure the gap, prove it with `engenho-diff` (engenho vs a
reference cluster), fix it with a case that goes red without the fix. Never work
around it in the consumer or lower the qualification; until it lands, report
which tier is blocked. A pass on engenho is a floor, not proof of upstream
behaviour, for any tier still listed as a gap.

The measured, source-mapped gaps (scalar type checking, OpenAPI coverage, OCI
pods on `native` nodes, Events, admission webhooks, namespace deletion) live in
engenho's [`docs/QUALIFICATION.md`](https://github.com/pleme-io/engenho/blob/main/docs/QUALIFICATION.md).
Add new gaps there, not here.
