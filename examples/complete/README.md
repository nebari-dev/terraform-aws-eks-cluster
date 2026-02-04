# Complete example

This example provisions a complete Amazon EKS cluster with multiple node groups, all required networking components (including a VPC, public and private subnets, VPC endpoints, NAT gateways, Internet Gateway, and security groups), IAM roles, and an EFS file system.

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
tofu destroy -auto-approve
```

> [!WARNING]
> This example creates multiple AWS resources that incur costs. Be sure to review the resources created and delete them when no longer needed.
