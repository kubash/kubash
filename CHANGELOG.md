# Changelog

## [v1.16.1] - 2026-10

A fixes-and-proof release: both supported targets now have a
real end-to-end boot test, and building them surfaced bugs
that v1.16.0 shipped — most importantly, the noble image
could not build at all, and secondary storage devices with
generated UUIDs were mounted with `UUID=null` (issue #68,
now closed; it was the repo's last open issue).

### Added

- End-to-end boot test (`.github/workflows/boot-test.yml`,
  dispatch-only): builds the target's Packer image on a
  KVM-enabled GitHub-hosted runner, boots a node from it,
  kubeadm-inits a cluster, and asserts a Ready node.
  Passing for both trixie and noble.
- Netplan rendering for secondary network interfaces on
  Ubuntu-family hosts: kubash now writes
  `/etc/netplan/60-kubash-<iface>.yaml` (Debian hosts keep
  ifupdown rendering).
- Regression suites `.ci/storage.bats` (guest-side storage
  mounts) and `.ci/qemu.bats` (host-side disk attach at
  provision time). The bats suite is now 66 tests.

### Fixed

- Noble image build: eight fixes (GRUB boot command, SSH
  handshake attempts, netplan-aware guest networking,
  packstrap package list and per-OS Docker repo, Zabbix
  repo, cleanup and swap-removal robustness). Noble builds
  and boots green.
- Trixie image build: five fixes found by the boot test
  (preseed early_command failure handling,
  `software-properties-common` removal on trixie, apt
  keyrings directory, gnupg package, pip
  `--break-system-packages`).
- Storage (issue #68): devices 1–3 whose UUID was generated
  at mount time were fsck'd, formatted, and recorded in
  fstab with the literal `UUID=null`. The four copy-pasted
  mount blocks are a single helper now; every device uses
  its own UUID.
- Makefile extras (Phase 4e-2): every remaining download is
  upstream-checksum-verified or TOFU-pinned; the minio
  server target was removed (its upstream distribution
  endpoint is gone) along with other dead downloads.

### Changed

- Removed two shadowed duplicate function definitions
  (the external-etcd kinit method and a fossil
  `install_default_docker` in packstrap), verified
  byte-identical behavior, and the dead fifth-storage-set
  attach lines in qemu-provisioner (no CSV schema defines
  a set 4).

## [v1.16.0] - 2026-10

The first release since v1.15.3 (2019). Kubash was modernized
end to end: CI, supported targets, Kubernetes versions, and
installer hygiene. No live-cluster boot test was performed for
this release; template and config correctness is verified with
kubeadm validation and the bats suite in CI.

### Added

- GitHub Actions CI: bash syntax check, ShellCheck at error
  severity, the bats suite, and docker bootstrap smoke tests
  (debian:trixie, ubuntu:24.04). The bats suite (58 tests)
  renders and validates the kubeadm templates and generated
  configs against real kubeadm binaries.
- kubeadm config templates for Kubernetes 1.35, 1.36, and 1.37
  (kubeadm.k8s.io/v1beta4), stacked and external-etcd variants.
- New build target: Ubuntu 24.04 (noble) with subiquity
  autoinstall, on all four Packer builders.
- `scripts/ci-iso-check` plus a weekly workflow that fails
  when a pinned ISO URL or checksum drifts (Debian point
  releases retire old ISO paths).
- Branch protection on master: the five CI checks and signed
  commits are required.

### Changed

- Debian target moved forward to trixie (Debian 13.7.0).
- Kubernetes defaults are now v1.36.5 (kubectl and cluster
  version) with crictl v1.36.0.
- Helm is v3.22.0 (pinned, checksum-verified); Packer is
  1.16.1 with pinned, checksum-verified plugins.
- Install one-liner now points at the kubash/kubash repo and
  can be pinned to this release tag.
- Makefile extras targets (gcloud, az, nvm, kustomize, opctl,
  aws, eksctl, minikube, talosctl) install pinned versions
  with checksum verification instead of piping remote scripts
  to bash or following `latest` URLs.
- Version-aware apiServer certSANs and etcd extraArgs in
  generated kubeadm configs (v1beta4 forms).

### Removed

- Kubernetes support for versions older than 1.35, including
  the 1.9-1.16 kubeadm templates, the pre-v1beta4 API mappings,
  and the 1.12 init methods. `determine_api_version` and the
  init dispatch refuse pre-1.35 versions with a clear message.
- Helm 2 / tiller, entirely.
- EOL build targets: Debian bullseye and older, xenial,
  bionic, buster, stretch, focal, centos7/8, and the broken
  generic ubuntu path (replaced by noble).
- The OpenShift initializer and the openshift-ansible
  submodule.
- Dead submodules (opensearch-devops, pupernetes), the
  Makefile kubeprod target (discontinued upstream), and the
  dead prometheus/monitoring Makefile chain.
- Legacy CI configurations (CircleCI, Travis, GitLab).

### Fixed

- Issue #67: secondary network interface values (netmask,
  network, broadcast, gateway) leaked across interfaces and
  hosts when CSV fields were left `null`; the envsubst inputs
  are now reset per interface.
- External-etcd kubeadm configs could not be generated for
  Kubernetes > 1.18 (a stale version check croaked); the
  dispatch now renders the versioned external template.
- Stacked-etcd SAN fragments used misspelled field names
  (serverCertSANS/peerCertSANS) that v1beta4 strict decoding
  rejects; corrected to serverCertSANs/peerCertSANs.
- The trixie template's preseed path pointed at a file the
  template never shipped.
- Four ShellCheck-era guard bugs where a missing `$` made
  feature checks test literal strings (keepalived setup never
  ran; MetalLB and OpenEBS install-method guards; a qemu
  network check).

## [v1.15.3] - 2019-08-28

Last release of the pre-modernization era; see the git history
for details.
