---
name: shoken
description: Verify a repo's first-contact surface — README status line, --help/--version, the install command, and every performance or capability claim — actually matches what the code does. Use before publishing or linking a repo publicly, when a README claim is cited as evidence, when a status ledger says SHIPPED, or on any repo a stranger might land on. Skip for private repos nobody outside the fleet will open.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "0.1.0"
  last_verified: "2026-08-30"
  domain_keywords:
    - "shoken"
    - "初見"
    - "README"
    - "first impression"
    - "install command"
    - "--help"
    - "status line"
    - "vaporware"
    - "ledger round-up"
    - "public surface"
---

# shoken (初見) — first sight

*What a stranger sees first must be true.*

A repo's **first-contact surface** is the two or three things someone
touches before they decide whether you are serious: the README's opening
screen, `--help`, `--version`, and the install command. This skill checks
that surface against the code.

It exists because the fleet's failure mode is **not** overclaiming. It is
the opposite and it is worse, because nothing ever flags it: a README
that says the project has not started, sitting on top of thousands of
passing tests. Overclaiming gets corrected by strangers. Underclaiming is
read as modesty and never re-examined — the same downward rot the org
CLAUDE.md warns about for coverage claims, applied to the front door.

## The rule

> **Every claim on the first-contact surface is a measurement with a date,
> or it is not on the surface.** A status line, a benchmark number, an
> install command and a ledger row are all claims. If you cannot run the
> thing that produces the number, delete the number.

## The five checks

Each check is a **typed operation over an injected Environment**, not a
shell pipeline and not a judgment call. The Environment carries exactly
four capabilities — run a process, read a file, list files, fetch a URL —
so every check is testable against a mock with no filesystem, no network
and no subprocess.

**NO SHELL applies here more than anywhere**, because this skill exists to
police discipline and an earlier draft of it specified all five checks as
shell one-liners, including a `curl | python3` pipe. That draft would have
taught the violation it was written to catch. What each check MEASURES is
below; `(defshoken ...)` is what runs it.

### 1. The binary answers the two commands everyone types first

**Measured:** the binary is invoked with `--help`, then `--version`, via a
typed `Command` built from typed pieces — never a shell string. Both must
exit 0 and write usage text to stdout.

A non-zero exit, an empty stdout, or a stderr carrying a panic or backtrace
marker is a FAIL. A binary that cannot be invoked at all is
**`CouldNotMeasure`, never a pass** — see the verdict rule below. **A stack trace here is the entire
first impression.** Measured 2026-08-30: `engenho --version` printed an
`anyhow` error plus a backtrace, on a binary serving 18 API groups with
3,556 passing tests.

Watch for the specific trap: if bare `<binary>` is a meaningful verb
(booting a daemon, say), then argv[1] is the *only* dispatch position and
`--help` classifies there like any other subcommand. It will fall through
to the unknown-verb arm unless you handle it. Accept all six spellings —
`--help -h help --version -V version`.

### 2. The status line matches the test count

**Measured:** the README's first screen is read and scanned for
not-yet-started markers (`pre-implementation`, `draft`, `WIP`, `not yet`);
the test count comes from the suite's own summary line. Both are values the
Environment supplies, so the comparison is a pure function over them.

If the README says *"pre-implementation"* and the suite is green with
four digits, the README is the defect. Two repos carried that exact line
on 2026-08-30 — engenho (3,556 tests) and magma (1,334 tests, plus a
verified mTLS go-plugin handshake against real provider binaries).

Say what is real, then say what is absent. `genkan/README.md` is the
in-fleet exemplar: *"Status: M0. There is no PAM linkage, no daemon, no
pixels, no libc, and no compositor. Do not read anything here as a working
login manager."* Nobody reading that feels misled in either direction.

### 3. The install command installs YOUR project

**Measured:** the registry is queried for the name the README tells people
to install, and the returned `repository` field is compared against this
repo's own remote. The comparison is the check — not the fetch. **A name you do not own
resolves to someone else's crate and the command still succeeds** — which
is worse than an error, because the user believes they installed you.

Measured 2026-08-30: sui's README told readers to `cargo install sui`.
`crates.io/crates/sui` is a MystenLabs reservation crate, v0.0.1,
*"This crate is reserved for the Sui project"*. The real package is
`pleme-io-sui` — published, current, and unmentioned. The badge rendered
MystenLabs' version number for months.

Apply the same check to every registry badge and every link in a
crate-listing table. Sub-crates often publish under plain names while
only the top-level one collided, so **check each row, not the pattern.**

### 4. Every number has a harness you can run

**Measured:** the README is scanned for numeric performance claims, and
each one must name a harness path that EXISTS. A claim whose harness cannot
be located is a ghost. A number with no
harness is a **ghost**: prose that reads as evidence and is not.

Measured 2026-08-30: sui's README claimed *"Exceeds CppNix 3× on 45/48
benchmarks."* No harness produced it, and this repo's own
`docs/SUI-EQUIVALENCE.md` already called it *"a GHOST … contradicted by
the only real sui-vs-nix harness"* — which reports **1.86× geomean and a
9× loss on deep recursion.** The disconfirming evidence was in-tree the
whole time; nothing linked the doc to the claim.

**A repo contradicting itself is the highest-cost defect on this list.**
An outsider who finds it stops trusting every other number you publish.

### 5. A ledger row means the CONTRACT is met, not that the code exists

If the repo publishes a status ledger, audit the SHIPPED rows:

**Measured:** for each row claiming SHIPPED, the module it names is
resolved and its **non-test callers are enumerated** — an actual reference
lookup, not a text scan, because a text scan counts a module's own
definition and its test fixtures as callers and thereby confirms whatever
it was asked to confirm.

**Zero callers means ABSENT, however complete the implementation.**

Measured 2026-08-30: engenho's ledger said `ServiceAccount tokens:
SHIPPED`. `sa_token.rs` was 397 lines of ed25519 issue/verify with 11
passing tests and **no non-test caller** — `authn.rs` still answered every
SA bearer with a 401. The row counted the code existing as the contract
being met. That is a **round-up**, and it is the same class as the fleet's
`only-mitigated → parse-time-rejected → truly-unrepresentable` tier
discipline: state the rung you are on, never the one above.

Ledgers rot in **both** directions — the same audit found `CNI / CSI:
ABSENT` on a repo that had since grown both crates. Re-measure the whole
table and re-date it; do not spot-fix one row.

## The verdict rule

Every check returns one of **four** values, and the fourth is the point:

| verdict | meaning |
|---|---|
| `Pass` | measured, and it holds |
| `Fail` | measured, and it does not hold |
| `NotApplicable` | the subject has no such surface — a library has no `--help` |
| `CouldNotMeasure` | the probe itself failed — binary missing, registry unreachable, file absent |

**`CouldNotMeasure` may never round to `Pass`.** A checker that reports
"could not run the binary" as green is committing the exact defect it
exists to catch, and it fails in the direction nobody investigates. This
is the same tier discipline the fleet applies elsewhere: state the rung you
are on, never the one above.

## When to run it

- **Before any link to a repo leaves the fleet** — a post, an issue, a
  PR description, a message to another team. This is the load-bearing
  moment; discovery is a single-day event with no second look.
- **Before citing a README claim as evidence**, including your own.
- **When a ledger row is about to be quoted.**
- **After landing a feature that changes what a ledger row should say** —
  the row moves in the same commit, or it is already stale.

## What this is not

It is not documentation work, and it is not marketing. It is **making the
repo's public claims and its code agree**, which is the same discipline
the fleet already applies to coverage claims and tier honesty — pointed at
the one surface nobody re-reads.

Nor does it license inflation. Every fix above made a claim **smaller and
truer**: magma stopped claiming HCL2 it cannot parse, sui traded a 3×
ghost for a measured 1.86× with a stated 9× loss, engenho downgraded a
SHIPPED row to ABSENT. The one thing that got *larger* was engenho's
status line, and only because 3,556 passing tests said so.

## Related

- **Naming laws** — `pleme-io/theory/NAMING.md`. Corpus-check any new
  name; reasoning that a word is free fails silently. `genkan` looked free
  and is a live repo.
- **Tier honesty** — `theory/UNREPRESENTABILITY.md` §II. Check 5 is that
  rule applied to a status table.
- **omote (表)** — the CLI *contract* as a typed test corpus. shoken asks
  whether `--help` exists and tells the truth; omote asks whether the
  whole CLI surface behaves. Run shoken first; it is cheaper.
