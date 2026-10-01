# engenho as a node's whole service layer

### engenho as a node's whole service layer

The direction for Linux hosts is that the host OS only boots the machine and runs
engenho, and everything else the host does runs on engenho as versioned Helm
releases. On the `native` backend a pod's image is a realised Nix closure run as a
host process. Every capability a host's services need from engenho (devices, host
networking, restart and ordering guarantees, secrets) is therefore engenho's
backlog, recorded in `docs/QUALIFICATION.md` with a failing case, the same as a
qualification gap below.

The step after that is the node itself: below a thin NixOS base, the system
generation, packages and services are one release, served as `NixClosure`,
`NixProfile` and `NodeGeneration` beside the Flux kinds, and a chart picks the
Kubernetes API face it runs against (`docs/FLEET-DESIGN.md` §9.1 and §10).
