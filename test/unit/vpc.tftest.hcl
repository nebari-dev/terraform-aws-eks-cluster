variables {
  project_name = "test-eks-cluster"
  node_groups = {
    test = {
      instance = "m5.large"
    }
  }
}

run "test_vpc_default" {
  command = plan

  assert {
    condition     = aws_vpc.main[0].cidr_block == "10.10.0.0/16"
    error_message = "VPC CIDR block should be default 10.10.0.0/16"
  }

  assert {
    condition     = aws_vpc.main[0].enable_dns_hostnames == true
    error_message = "VPC should have DNS hostnames enabled"
  }

  assert {
    condition     = aws_vpc.main[0].enable_dns_support == true
    error_message = "VPC should have DNS support enabled"
  }
}

run "test_custom_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr_block = "10.20.0.0/16"
  }

  assert {
    condition     = aws_vpc.main[0].cidr_block == "10.20.0.0/16"
    error_message = "VPC CIDR should match custom value"
  }
}

run "test_vpc_cidr_invalid" {
  command = plan

  variables {
    vpc_cidr_block = "10.10.0.0"
  }

  expect_failures = [
    var.vpc_cidr_block,
  ]
}

run "test_vpc_not_created_with_existing_subnets" {
  command = plan

  variables {
    existing_subnet_ids = ["subnet-12345", "subnet-67890"]
  }

  assert {
    condition     = length(aws_vpc.main) == 0
    error_message = "VPC should not be created when existing subnets are provided"
  }

  assert {
    condition     = length(aws_subnet.private) == 0
    error_message = "Private subnets should not be created when existing subnets are provided"
  }

  assert {
    condition     = length(aws_subnet.public) == 0
    error_message = "Public subnets should not be created when existing subnets are provided"
  }
}

run "test_subnets_created_per_az" {
  command = plan

  variables {
    availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Should create 3 private subnets for 3 AZs"
  }

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "Should create 3 public subnets for 3 AZs"
  }
}

run "test_nat_gateway_per_az" {
  command = plan

  variables {
    availability_zones = ["us-west-2a", "us-west-2b"]
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 2
    error_message = "Should create one NAT gateway per AZ"
  }

  assert {
    condition     = length(aws_eip.nat) == 2
    error_message = "Should create one EIP per NAT gateway"
  }
}

run "test_security_group_created" {
  command = plan

  assert {
    condition     = length(aws_security_group.cluster) == 1
    error_message = "Security group should be created by default"
  }
}

run "test_security_group_not_created_with_existing" {
  command = plan

  variables {
    existing_security_group_id = "sg-12345"
  }

  assert {
    condition     = length(aws_security_group.cluster) == 0
    error_message = "Security group should not be created when existing one is provided"
  }
}

run "test_security_group_rules" {
  command = plan

  assert {
    condition     = length(aws_security_group_rule.cluster_ingress_https) == 1
    error_message = "HTTPS ingress rule should be created"
  }

  assert {
    condition     = length(aws_security_group_rule.cluster_ingress_kubelet) == 1
    error_message = "Kubelet ingress rule should be created"
  }

  assert {
    condition     = length(aws_security_group_rule.cluster_egress_all) == 1
    error_message = "All egress rule should be created"
  }
}

run "test_private_subnet_cidrs" {
  command = plan

  variables {
    vpc_cidr_block     = "10.10.0.0/16"
    availability_zones = ["us-west-2a", "us-west-2b"]
  }

  assert {
    condition     = aws_subnet.private[0].cidr_block == "10.10.128.0/20"
    error_message = "First private subnet should be 10.10.128.0/20"
  }

  assert {
    condition     = aws_subnet.private[1].cidr_block == "10.10.144.0/20"
    error_message = "Second private subnet should be 10.10.144.0/20"
  }
}

run "test_public_subnet_cidrs" {
  command = plan

  variables {
    vpc_cidr_block     = "10.10.0.0/16"
    availability_zones = ["us-west-2a", "us-west-2b"]
  }

  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.10.0.0/20"
    error_message = "First public subnet should be 10.10.0.0/20"
  }

  assert {
    condition     = aws_subnet.public[1].cidr_block == "10.10.16.0/20"
    error_message = "Second public subnet should be 10.10.16.0/20"
  }
}

run "test_route_tables_per_az" {
  command = plan

  variables {
    availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  assert {
    condition     = length(aws_route_table.private) == 3
    error_message = "Should create one route table per AZ for private subnets"
  }

  assert {
    condition     = length(aws_route_table.public) == 1
    error_message = "Should create one route table for all public subnets"
  }
}

run "test_vpc_endpoints_created" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 9
    error_message = "Should create 9 interface VPC endpoints (ec2, ecr.api, ecr.dkr, sts, eks, eks-auth, logs, elasticloadbalancing, autoscaling)"
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 1
    error_message = "Should create 1 S3 gateway endpoint"
  }
}

run "test_vpc_endpoints_not_created_with_existing_subnets" {
  command = plan

  variables {
    existing_subnet_ids = ["subnet-12345", "subnet-67890"]
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 0
    error_message = "Interface endpoints should not be created when using existing subnets"
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 0
    error_message = "S3 endpoint should not be created when using existing subnets"
  }
}

run "test_subnet_tags_for_kubernetes" {
  command = plan

  assert {
    condition     = aws_subnet.public[0].tags["kubernetes.io/role/elb"] == "1"
    error_message = "Public subnets should have kubernetes.io/role/elb tag for AWS Load Balancer Controller"
  }

  assert {
    condition     = aws_subnet.private[0].tags["kubernetes.io/role/internal-elb"] == "1"
    error_message = "Private subnets should have kubernetes.io/role/internal-elb tag for internal load balancers"
  }
}
