# Passes subnet IDs that are unknown at plan as existing_private_subnet_ids, as when
# the subnets are created in the same apply (examples/existing-resources). The mocked
# AWS provider makes up IDs at plan, so terraform_data stands in for the subnets: its
# id is only known after apply.

resource "terraform_data" "subnet" {
  count = 2
}

module "cluster" {
  source = "../../.."

  project_name                = "az-test"
  create_vpc                  = false
  existing_vpc_id             = "vpc-123"
  existing_private_subnet_ids = terraform_data.subnet[*].id

  node_groups = {
    user-a = {
      instance           = "m5.xlarge"
      availability_zones = ["us-west-2a"]
    }
  }
}
