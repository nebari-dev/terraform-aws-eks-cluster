# Suspend the AZRebalance process on the ASGs backing EKS managed node groups
# that opt in via `node_groups[*].suspend_az_rebalance = true`.
#
# EKS-managed node groups create ASGs with AZRebalance ENABLED by default.
# AZRebalance terminates and relaunches instances to keep AZs balanced, which is
# disruptive for any workload and an outright data-loss risk for stateful/storage
# node groups (e.g. Longhorn): a storage node can be terminated purely to
# rebalance AZs, taking its replica data with it. cluster-autoscaler manages real
# capacity changes, so AZRebalance provides no benefit on managed node groups.
#
# Opt-in and per-node-group by design (default false) so this introduces no
# behavior change for node groups that don't request it. EKS managed node groups
# do not expose ASG suspended-processes natively, so this is applied
# post-creation via the AWS CLI against each opted-in node group's backing ASG.
# Requires the apply principal to have `autoscaling:SuspendProcesses` and the
# `aws` CLI to be available in the apply environment.

resource "terraform_data" "suspend_az_rebalance" {
  for_each = { for name, cfg in var.node_groups : name => cfg if cfg.suspend_az_rebalance }

  # Re-run if the node group's backing ASG(s) change (e.g. node group recreated).
  triggers_replace = [
    join(",", module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      set -eu
      for asg in ${join(" ", module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names)}; do
        echo "Suspending AZRebalance on ASG $asg (node group ${each.key})"
        aws autoscaling suspend-processes \
          --auto-scaling-group-name "$asg" \
          --scaling-processes AZRebalance \
          --region ${data.aws_region.current.region}
      done
    EOT
  }
}
