# AGENTS.md

Guidance for contributors and AI coding agents working in this repository.

This file follows the [AGENTS.md](https://agents.md) convention and is read by Claude Code, Codex, Cursor, Aider, Jules, and other agent tooling, as well as by humans.

## Project Overview

**terraform-aws-eks-cluster** is an OpenTofu/Terraform module that provisions an Amazon EKS cluster for Nebari, along with the networking, IAM, storage and Pod Identity pieces the platform needs on top of it. It is published to the Terraform Registry as [`nebari-dev/eks-cluster/aws`](https://registry.terraform.io/modules/nebari-dev/eks-cluster/aws).

The module is a **wrapper**: the heavy lifting is done by pinned [`terraform-aws-modules`](https://github.com/terraform-aws-modules) modules (`vpc`, `eks`, `efs`, `eks-pod-identity`). This repo decides how they are wired together, adds a few small local submodules, and guards the inputs with validations and preconditions so mistakes fail at plan rather than halfway through an apply.

### Who consumes this module

The main consumer is [`nebari-infrastructure-core`](https://github.com/nebari-dev/nebari-infrastructure-core) (NIC). Its AWS cluster provider embeds `.tf` templates under `pkg/providers/cluster/aws/templates/` that call this module from the registry with a pinned `version`, and pass most of its variables straight through. NIC also installs the things this module only prepares IAM for (AWS Load Balancer Controller, Cluster Autoscaler, Longhorn, the FSx for OpenZFS CSI driver).

That makes the module's **inputs and outputs a contract**. Renaming or removing a variable or output, changing a default, or changing what a resource is keyed by breaks or silently changes NIC deployments on the next version bump there. When you change the interface, say so in the PR description and expect a follow-up PR in NIC.

### Core Architecture Principles

1. **Thin wrapper over pinned upstream modules.** Prefer configuring an upstream module over writing resources by hand. Every registry module is pinned to an exact version.
2. **Bring your own resources.** Each of `create_vpc`, `create_iam_roles` and `create_security_group` has matching `existing_*` inputs, and both paths must keep working (see `examples/existing-resources`).
3. **Fail at plan, not at apply.** Input rules live in `validation` blocks; cross-resource rules live in `precondition`s (on `terraform_data` resources in `main.tf`, or on the resource they protect). Write them so they still plan when values such as subnet IDs are unknown until apply.
4. **Don't replace stateful resources by accident.** Subnets, node groups and the FSx filesystem are keyed and ordered deliberately. A change that reorders a list or rekeys a map can replace a subnet or destroy data; if it is unavoidable, document it in the variable description and the PR.
5. **The module provisions infrastructure and identities, not in-cluster software.** Only EKS-managed addons are installed here. For anything installed by Helm (load balancer controller, autoscaler, Longhorn, FSx CSI), the module creates the IAM role and Pod Identity association and leaves the install to the consumer.
6. **No provider configuration.** The module never declares `provider` blocks (`providers.tf` is a placeholder); callers configure the AWS provider.

## Common Development Commands

All commands use **OpenTofu** (`tofu`), not `terraform`. CI pins OpenTofu 1.11.2; the root module requires `>= 1.9` and the AWS provider `>= 6.0`.

```bash
make help            # list targets
make init            # tofu init + install pre-commit hooks
make install-tools   # pre-commit, terraform-docs, tflint, Go test deps
make fmt             # tofu fmt -recursive .
make validate        # tofu init -backend=false && tofu validate && tflint
make lint            # fmt + validate + pre-commit run --all-files
make test-unit       # native tofu tests: modules/userdata, modules/fsx-openzfs, root (no AWS needed)
make test            # test-unit, then the Terratest integration suite (deploys real clusters)
make docs            # regenerate the README's terraform-docs section (runs in Docker)
make clean           # remove .terraform, lock files, plans and local state
```

Run a single native test file from the root:

```bash
tofu init -backend=false && tofu test -filter=tests/single_az.tftest.hcl
```

`make test` creates real EKS clusters in AWS and takes up to 90 minutes. Don't run it unless you have credentials for a sandbox account and mean to.

## High-Level Architecture

### Repository Layout

```
main.tf                 # Module calls: vpc, iam, eks, pod identities, vpc_endpoints, efs,
                        # fsx_openzfs, longhorn_backup, node_userdata; plan-time AZ checks
locals.tf               # Most of the logic: AZ selection, subnet CIDRs, single-AZ layout,
                        # node group mapping, endpoint service lists, EFS mount targets
variables.tf            # Public inputs, with validations
outputs.tf              # Public outputs
versions.tf             # required_version / required_providers
providers.tf            # Placeholder only; the module configures no providers

modules/
  iam/                  # One shared node IAM role, instead of one per node group
  userdata/             # Extra CA bundle hooks per AMI (AL2023 cloud-init, Bottlerocket TOML)
  vpc-endpoints/        # Interface + gateway VPC endpoints and their security group
  fsx-openzfs/          # FSx for OpenZFS filesystem, NFS security group, CSI Pod Identity
  longhorn-backup/      # S3 bucket + Pod Identity for Longhorn backups

examples/
  complete/             # Module creates the VPC, IAM roles and security group
  existing-resources/   # Module uses a VPC, subnets, SG and IAM roles created alongside it

tests/                  # Native tofu tests for the root module (mocked AWS provider)
  fixtures/             # Helper configurations used by those tests
test/                   # Terratest (Go) integration suite that deploys the examples
```

### How the pieces fit

```
var.* ──> locals.tf ──┬─> module.vpc            (only when create_vpc)
                      ├─> module.iam            (shared node role, only when create_iam_roles)
                      ├─> module.node_userdata  (one per node group)
                      ├─> module.eks            (cluster, addons, managed node groups)
                      ├─> pod identity modules  (EBS CSI, EFS CSI, LB controller, autoscaler)
                      ├─> module.vpc_endpoints  (only when create_vpc)
                      ├─> module.efs            (only when efs_enabled)
                      ├─> module.fsx_openzfs    (only when fsx_openzfs_enabled)
                      └─> module.longhorn_backup
```

Optional modules use `count`, and their outputs are read with `one(module.x[*].attr)` so they resolve to `null` when disabled.

### Networking

- With `create_vpc = true`, subnets are carved from `vpc_cidr_block` with `cidrsubnet(cidr, 4, i)`: public subnets use indices 0-7, private subnets 8-15, one of each per AZ, in the order of `availability_zones`. **Reordering `availability_zones` replaces subnets.**
- If `availability_zones` is empty, the first three available AZs in the region are used.
- One NAT gateway per AZ (a single one for single-AZ clusters), internal-ELB tags on private subnets, ELB tags on public subnets.
- VPC endpoints (ec2, ecr, sts, eks, eks-auth, logs, elasticloadbalancing, autoscaling, plus efs/fsx when enabled, and an S3 gateway endpoint) are only created for a VPC the module owns.

### Single-AZ clusters

EKS needs control plane subnets in two AZs. When the module creates a VPC with **one** AZ (`local.single_az`), it adds a private subnet in a second AZ that only the control plane uses. Nodes, NAT, endpoints, EFS and FSx stay in the first AZ, and only that AZ's subnet gets the internal-ELB tag. The second AZ is picked from `data.aws_availability_zones.control_plane` and exposed as the `control_plane_availability_zone` output; appending it to `availability_zones` later grows the cluster to two AZs without touching the control plane.

The exclusion list in that data source (`exclude_zone_ids`) holds zone IDs where EKS doesn't run. **Only ever add to it**: the pick is recomputed on every plan, so changing the list can move the control plane AZ under a running cluster (see #56).

For existing VPCs, `existing_control_plane_subnet_ids` plays the same role, and `terraform_data.control_plane_availability_zones` fails the plan if the control plane subnets are all in one AZ.

### Node groups

`var.node_groups` is a simplified map that `local.node_groups` translates into the EKS module's `eks_managed_node_groups` format. Things worth knowing before touching it:

- All node groups share one node IAM role (`modules/iam`, or `existing_node_iam_role_arn`).
- `disk_size` is applied through `block_device_mappings`, because the EKS module's custom launch template makes EKS ignore the node group's `disk_size`.
- `ami_release_version`: `null` keeps whatever release the group runs, `"latest"` follows SSM on every plan, anything else pins a release (validated against `kubernetes_version`).
- `availability_zones` restricts a group to the private subnets in those AZs; `terraform_data.node_group_availability_zones` fails the plan for AZs the cluster has no subnet in. Existing subnets are looked up by position (`data.aws_subnet.existing_private`) because their IDs may be unknown at plan.
- `extra_ca_bundle` is rendered per AMI type by `modules/userdata` and is a no-op when unset.

### Security groups

- With `create_security_group = true`, EKS's primary cluster security group is attached to nodes, which is also what lets EFS mount targets accept NFS from nodes without a separate rule.
- The upstream module's `kubernetes.io/cluster/<name>` tag is **removed from the node security group on purpose**. EKS already puts that tag on the primary SG, and with two tagged SGs the AWS Load Balancer Controller silently fails to add its rules. Don't put it back.
- `node_security_group_additional_rules` is passed straight to the EKS module (NIC uses it for the Longhorn webhook ports).

### Pod Identity

All workload IAM uses EKS Pod Identity via `terraform-aws-modules/eks-pod-identity`, with names prefixed by `var.project_name`:

- **EKS-managed addons** (EBS CSI, EFS CSI) get their association through `module.eks`'s `addons[*].pod_identity_association`.
- **Helm-installed components** (load balancer controller, cluster autoscaler, Longhorn, FSx CSI) get their association through the pod identity module's `associations` argument, bound to the service account the consumer's chart uses.

IRSA (`enable_irsa`) is still on by default for consumers that need it.

## Key Development Patterns

### Adding or changing an input

1. Add the variable to `variables.tf` (or the submodule that owns it) with a `description`, a `type`, and a `validation` where the value has a known shape. Error messages should say what a valid value looks like.
2. Wire it through `locals.tf` / `main.tf`.
3. Add or update native tests under `tests/` (or the submodule's `*.tftest.hcl`), including the cases the validation should reject (`expect_failures`).
4. Run `make docs` so the README tables match.
5. If NIC should expose it, note that in the PR; NIC adds it to its templates after a release.

Validation that only concerns a submodule lives in that submodule; the root variable's description says "Validated by the <name> submodule" instead of duplicating the rule (see the `fsx_openzfs_*` inputs).

### Adding an output

Add it to `outputs.tf` with a `description` (tflint enforces this). For optional features, make the output `null` when the feature is disabled and say so in the description. Run `make docs`.

### Adding a submodule

1. Create `modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf` and `versions.tf` (same constraints as the root).
2. Call it from `main.tf` with `count` (or `for_each`) so it can be turned off, passing `project_name` and `tags`.
3. If it has native tests, add it to the `test-unit` target in the `Makefile` **and** the `test-unit` matrix in `.github/workflows/ci.yml`.

### Bumping an upstream module

Change the exact `version` in `main.tf`, read the upstream changelog for renamed inputs and resource address changes, and run `tofu plan` against an existing cluster (or both examples) to check nothing is replaced unexpectedly. Address changes need `moved` blocks.

### Adding a Pod Identity for a new component

Follow `aws_lb_controller_pod_identity` / `cluster_autoscaler_pod_identity` in `main.tf`: gate it behind an `enable_*` variable, name it `"${var.project_name}-<short>"`, attach the upstream module's built-in policy if there is one, associate it with the chart's service account and namespace, and output the role ARN.

## Conventions

- **OpenTofu first.** Commands, docs and CI use `tofu`.
- **Pin registry modules exactly** (`version = "x.y.z"`); tflint's `terraform_module_pinned_source` rule is on.
- **Document every variable and output**; tflint's `terraform_documented_variables` / `terraform_documented_outputs` rules are on, and the descriptions become the README.
- **Comments explain why**, especially for workarounds of upstream or AWS behavior (see the node SG tag and `disk_size` comments). Keep that style; a non-obvious line without its reason will get "fixed" by the next person.
- **Name resources from `var.project_name`** and pass `tags = var.tags` to everything that takes tags.
- **IAM name prefixes are limited to 38 characters.** Keep the suffix you add to `project_name` short.
- **Key `for_each` by stable values.** When the values may be unknown at plan (subnet IDs created in the same apply), key by position, as `data.aws_subnet.existing_*` does.
- **Destructive behavior is documented in the variable description** (for example, reordering `existing_private_subnet_ids` replaces the FSx filesystem; changing a node group's `availability_zones` replaces it).
- Never commit `*.tfvars`, state, lock files or `*_override.tf(.json)`; they are gitignored.

## Testing

### Native tests (`tofu test`)

- `tests/*.tftest.hcl` cover the root module; `modules/userdata` and `modules/fsx-openzfs` have their own.
- They use `mock_provider "aws"` and `command = plan`, so they need no credentials and create nothing. Mock data sources return just enough (partition, caller identity, AZ names, policy JSON, ARNs) for the plan to succeed. `plan_options { target = [...] }` keeps a run focused.
- Plan-time edge cases, like subnet IDs unknown until apply, are covered with fixtures under `tests/fixtures/` that call the module as a child.
- Known limit: they can check this module's locals and plan-time failures, but not what the module actually passes into the upstream modules (#53).
- CI runs them for every PR touching `.tf` or `.tftest.hcl` files. Add tests for new logic and validations, and **never disable a test to get CI green**.

### Integration tests (Terratest)

- `test/module_test.go` deploys `examples/complete` and `examples/existing-resources` in `us-west-2`, each also in a single-AZ variant, then checks the EBS CSI driver provisions and mounts a volume and that the FSx outputs are populated, and destroys everything.
- Each run copies the example to a temp dir and writes a `test_override.tf.json` that enables public endpoint access, admin permissions and FSx destroy flags. Extra per-test module arguments go through `runExample`'s `moduleArgs`.
- `namePrefix` must stay at 14 characters or fewer because it ends up in IAM name prefixes.
- CI runs the suite (`.github/workflows/test.yml`) when a draft PR is marked ready for review, on pushes to `main`, and on manual dispatch, one run at a time. A PR opened as ready for review does not trigger it. It costs real money and takes a long time.
- Runs have been known to leave EBS volumes behind (#52).

## CI

| Workflow | Trigger | What it checks |
| --- | --- | --- |
| `ci.yml` | PRs and pushes to `main` touching `*.tf` / `*.tftest.hcl` | `tofu fmt -check`, `tofu validate`, native tests (root + submodule matrix), tflint, README docs up to date |
| `test.yml` | Draft PR marked ready for review, push to `main`, manual | Terratest integration suite in AWS |
| `add-to-project.yaml` | Issue or PR opened | Adds it to the Nebari project board |

## Documentation

- **`README.md`**: the section between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` is generated by terraform-docs from `.terraform-docs.yml` (which also holds the Usage example). Don't edit it by hand; run `make docs` (or let the pre-commit hook do it). CI fails if it is stale.
- **`examples/*/README.md`**: hand-written; update them when an example deploys something new.
- **`SECURITY.md`**: report vulnerabilities through GitHub private vulnerability reporting, never public issues.

## Releases

Releases are GitHub Releases tagged `vX.Y.Z` with generated notes. The Terraform Registry picks up new tags, and NIC moves to a new version by bumping the `version` in its AWS templates. Call out interface changes and anything that replaces resources so the release notes and the NIC bump can account for them.

## Contribution Workflow

1. Branch from `main` with a conventional prefix (`feat/`, `fix/`, `chore/`, `docs/`, `test/`), adding the issue number when there is one.
2. Make the change and add tests.
3. Run the pre-commit checklist below.
4. Use **Conventional Commits** for messages, with `Closes #<N>` when resolving an issue.
5. Open the PR as a draft, and mark it ready for review when you want the integration suite to run against it.

## Pre-Commit Checklist

1. **Format:** `make fmt`
2. **Validate + lint:** `make validate` (tofu validate + tflint)
3. **Native tests:** `make test-unit`
4. **Docs:** `make docs` if any variable, output, module call or version changed
5. **Interface changes** to variables or outputs are called out in the PR for NIC
6. **No unexpected replacements:** for changes to keys, ordering, or upstream versions, check a plan against an existing deployment

`pre-commit run --all-files` covers formatting, validation, docs and tflint in one go once `make init` has installed the hooks.

## Keeping This File Current

This file is hand-written. If you change a convention, the layout, the CI workflows, or how NIC consumes the module, update it in the same PR.
