package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExampleClusterComplete(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../examples/cluster-complete",
		TerraformBinary: "tofu",
	})

	// Make sure to destroy resources at the end of the test, regardless of whether the test passes or fails
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)
}

func TestExampleClusterOnly(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../examples/cluster-only",
		TerraformBinary: "tofu",
	})

	// Make sure to destroy resources at the end of the test, regardless of whether the test passes or fails
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)
}
