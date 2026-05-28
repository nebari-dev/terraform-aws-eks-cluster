variable "extra_ca_bundle" {
  description = "Optional base64-encoded PEM bundle to install into the node OS trust store. Unset means no changes."
  type        = string
  default     = null
}

variable "ami_type" {
  description = "EKS managed node group AMI type. Used to pick AL2023/AL2 shell-script vs Bottlerocket TOML."
  type        = string
}

locals {
  is_bottlerocket = startswith(var.ami_type, "BOTTLEROCKET_")

  # AL2023 is RHEL-based: drop anchors under /etc/pki/ca-trust/source/anchors and run
  # `update-ca-trust extract` so the bundle ends up in /etc/pki/tls/certs/ca-bundle.crt
  # before nodeadm/kubelet start. The same script works on AL2.
  al2_pre_nodeadm_script = var.extra_ca_bundle == null ? null : <<-EOT
    #!/bin/bash
    set -euo pipefail
    install -d -m 0755 /etc/pki/ca-trust/source/anchors
    echo '${var.extra_ca_bundle}' | base64 -d > /etc/pki/ca-trust/source/anchors/org-ca.crt
    chmod 0644 /etc/pki/ca-trust/source/anchors/org-ca.crt
    update-ca-trust extract
  EOT

  bottlerocket_settings = var.extra_ca_bundle == null ? null : <<-EOT
    [settings.pki.org-ca]
    data = "${var.extra_ca_bundle}"
    trusted = true
  EOT
}

output "cloudinit_pre_nodeadm" {
  description = "cloud-init pre-nodeadm parts for AL2023/AL2 node groups. Null when no extra CA bundle is requested or when the AMI is Bottlerocket."
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
