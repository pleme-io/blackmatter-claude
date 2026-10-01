# Why engenho: the short version

The long version is engenho's [`docs/WHY-ENGENHO.md`](https://github.com/pleme-io/engenho/blob/main/docs/WHY-ENGENHO.md).

- **"Why engenho / is this worth it / what is it for?"** → read
  [`docs/WHY-ENGENHO.md`](https://github.com/pleme-io/engenho/blob/main/docs/WHY-ENGENHO.md). Short version:
  Kubernetes and Nomad are the same shape in different packaging (server/client
  + Raft + reconciliation), engenho is Nomad's packaging speaking Kubernetes'
  contract, and the payoff is **testing / simulation / embedding** — because
  Raft determinism and deterministic-simulation determinism are the SAME
  requirement, and engenho already paid for it (`mint_uid` is BLAKE3-derived,
  `relogio` is a typed clock seam, every side effect is behind an Environment
  trait). The named next step is auditing away stray `SystemTime::now()` calls.
