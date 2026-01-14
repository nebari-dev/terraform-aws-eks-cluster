# Cluster Only Example

This example provisions an Amazon EKS cluster and multiple node groups on top of an existing VPC, subnets, security groups, and IAM roles. It showcases how to use the module in a scenario where the networking components and the IAM roles are managed outside of the module.

For convenience, this example includes separate Terraform configurations in the `networking/` and `iam/` directories that automatically create the required VPC, subnets, security groups, and IAM roles. You can also modify the example to use your own existing resources by updating the relevant variables in `main.tf`

## Usage

To deploy this example, you need to have [OpenTofu installed](https://opentofu.org/docs/intro/install/) and AWS credentials configured. Then, follow these steps:

1. Clone this repository:

   ```bash
   git clone https://github.com/nebari-dev/terraform-aws-eks-cluster.git
   ```

2. Navigate to the example directory:

   ```bash
   cd terraform-aws-eks-cluster/examples/cluster-complete
   ```

3. Initialize the OpenTofu working directory:

   ```bash
   tofu init
   ```

4. Apply the configuration to create the resources and confirm when prompted after reviewing the plan:

   ```bash
   tofu apply
   ```

To destroy the resources created by this example, run:

```bash
tofu destroy
```

> [!WARNING]
> This example creates multiple AWS resources that incur costs. Be sure to review the resources created and delete them when no longer needed.
