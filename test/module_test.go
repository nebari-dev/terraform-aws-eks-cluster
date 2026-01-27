package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestExampleComplete(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../examples/complete",
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_name": "test-complete-" + uniqueID,
		},
	})

	// Make sure to destroy resources at the end of the test, regardless of whether the test passes or fails
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)
}

func TestExampleExistingResources(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    "../examples/existing-resources",
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_name": "test-existing-" + uniqueID,
		},
	})

	// Make sure to destroy resources at the end of the test, regardless of whether the test passes or fails
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)
}
