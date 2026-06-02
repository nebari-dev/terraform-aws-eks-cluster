variable "extra_ca_bundle" {
  description = "Optional base64-encoded PEM bundle to install into the node OS trust store. Unset means no changes."
  type        = string
  default     = null

  # The bundle is interpolated into a single-quoted shell command and a TOML
  # basic string in the templates below. The base64 alphabet excludes quotes
  # and backslashes, so a value that decodes cleanly cannot break out of either
  # context. Enforcing it here keeps that guarantee local to the templating,
  # rather than relying on the parent module having already validated it.
  validation {
    condition     = var.extra_ca_bundle == null || can(base64decode(var.extra_ca_bundle))
    error_message = "extra_ca_bundle must be a valid base64-encoded string."
  }
}

variable "ami_type" {
  description = "EKS managed node group AMI type. Used to pick the AL2023 shell-script vs the Bottlerocket TOML."
  type        = string
}

locals {
  # Binary dispatch: Bottlerocket -> TOML path, everything else -> AL2023 bash
  # shellscript. If this module ever needs to support Windows AMI types
  # (WINDOWS_CORE_*, WINDOWS_FULL_*), revisit this check — they would currently
  # fall through to the AL2023 path and silently break boot.
  is_bottlerocket = startswith(var.ami_type, "BOTTLEROCKET_")

  # AL2023 is RHEL-based: drop anchors under /etc/pki/ca-trust/source/anchors and run
  # `update-ca-trust extract` so the bundle ends up in /etc/pki/tls/certs/ca-bundle.crt
  # before nodeadm/kubelet start.
  al2_pre_nodeadm_script = var.extra_ca_bundle == null ? null : templatefile(
    "${path.module}/templates/install-extra-ca-bundle.sh.tftpl",
    { extra_ca_bundle = var.extra_ca_bundle }
  )

  bottlerocket_settings = var.extra_ca_bundle == null ? null : templatefile(
    "${path.module}/templates/bottlerocket-ca.toml.tftpl",
    { extra_ca_bundle = var.extra_ca_bundle }
  )
}

output "cloudinit_pre_nodeadm" {
  description = "cloud-init pre-nodeadm parts for AL2023 node groups. Null when no extra CA bundle is requested or when the AMI is Bottlerocket."
  value = (var.extra_ca_bundle == null || local.is_bottlerocket) ? null : [
    {
      content      = local.al2_pre_nodeadm_script
      content_type = "text/x-shellscript; charset=\"us-ascii\""
      filename     = "install-extra-ca-bundle.sh"
    }
  ]
}

output "bootstrap_extra_args" {
  description = "Bottlerocket bootstrap_extra_args TOML for installing the extra CA bundle. Null when no extra CA bundle is requested or when the AMI is not Bottlerocket."
  value       = local.is_bottlerocket ? local.bottlerocket_settings : null
}
