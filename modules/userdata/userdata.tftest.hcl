variables {
  # Base64-encoded "DUMMY-CA-PEM-DATA\n" - not a real certificate, just a fixed payload
  # for assertions against the rendered userdata.
  extra_ca_bundle = "RFVNTVktQ0EtUEVNLURBVEEK"
}

run "al2023_renders_cloudinit_pre_nodeadm" {
  command = plan

  variables {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  assert {
    condition     = output.bootstrap_extra_args == null
    error_message = "AL2023 must not use bootstrap_extra_args; that is a Bottlerocket-only path."
  }

  assert {
    condition     = length(output.cloudinit_pre_nodeadm) == 1
    error_message = "AL2023 should produce exactly one cloud-init pre-nodeadm part."
  }

  assert {
    condition     = output.cloudinit_pre_nodeadm[0].content_type == "text/x-shellscript; charset=\"us-ascii\""
    error_message = "Cloud-init part must declare a shellscript MIME content type so cloud-init executes it."
  }

  # Literal base64 (not ${var.extra_ca_bundle}) so the assertion isn't coupled
  # to the same variable the production code interpolates — if the module ever
  # transformed the bundle on its way into the template, this would still catch it.
  assert {
    condition     = strcontains(output.cloudinit_pre_nodeadm[0].content, "echo 'RFVNTVktQ0EtUEVNLURBVEEK' | base64 -d > /etc/pki/ca-trust/source/anchors/org-ca.crt")
    error_message = "Pre-nodeadm script must decode the provided bundle into the AL2023 trust anchor directory."
  }

  assert {
    condition     = strcontains(output.cloudinit_pre_nodeadm[0].content, "update-ca-trust extract")
    error_message = "Pre-nodeadm script must run `update-ca-trust extract` so the bundle reaches /etc/pki/tls/certs/ca-bundle.crt before kubelet starts."
  }
}

run "al2023_arm_renders_cloudinit_pre_nodeadm" {
  command = plan

  variables {
    ami_type = "AL2023_ARM_64_STANDARD"
  }

  assert {
    condition     = output.cloudinit_pre_nodeadm != null && output.bootstrap_extra_args == null
    error_message = "Non-Bottlerocket AMI variants (incl. ARM, NVIDIA) must take the cloud-init path."
  }
}

run "bottlerocket_renders_toml_settings" {
  command = plan

  variables {
    ami_type = "BOTTLEROCKET_x86_64"
  }

  assert {
    condition     = output.cloudinit_pre_nodeadm == null
    error_message = "Bottlerocket does not run cloud-init shellscripts; cloudinit_pre_nodeadm must be null."
  }

  assert {
    condition     = strcontains(output.bootstrap_extra_args, "[settings.pki.org-ca]")
    error_message = "Bottlerocket settings must declare [settings.pki.org-ca]."
  }

  # Literal base64 (not ${var.extra_ca_bundle}) — same reasoning as the AL2023 assertion above.
  assert {
    condition     = strcontains(output.bootstrap_extra_args, "data = \"RFVNTVktQ0EtUEVNLURBVEEK\"")
    error_message = "Bottlerocket pki.data must contain the base64-encoded bundle verbatim."
  }

  assert {
    condition     = strcontains(output.bootstrap_extra_args, "trusted = true")
    error_message = "Bottlerocket pki bundle must be marked trusted; otherwise it is not added to the trust store."
  }
}

run "no_bundle_is_a_noop_on_al2023" {
  command = plan

  variables {
    ami_type        = "AL2023_x86_64_STANDARD"
    extra_ca_bundle = null
  }

  assert {
    condition     = output.cloudinit_pre_nodeadm == null && output.bootstrap_extra_args == null
    error_message = "When extra_ca_bundle is unset, both outputs must be null so launch templates do not churn."
  }
}

run "no_bundle_is_a_noop_on_bottlerocket" {
  command = plan

  variables {
    ami_type        = "BOTTLEROCKET_x86_64"
    extra_ca_bundle = null
  }

  assert {
    condition     = output.cloudinit_pre_nodeadm == null && output.bootstrap_extra_args == null
    error_message = "When extra_ca_bundle is unset on Bottlerocket, both outputs must be null."
  }
}
