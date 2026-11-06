package test

import (
	"encoding/json"
	"maps"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	corev1 "k8s.io/api/core/v1"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	waitRetries  = 30
	waitInterval = 10 * time.Second
)

// writeTestOverride writes a Terraform JSON override file into an example directory.
// The override file uses Terraform's override mechanism to change values that are
// intentionally hardcoded in the examples and that are needed for the tests to run,
// plus moduleArgs, extra arguments for the example's cluster module. String values
// can reference the example's resources with "${...}", since Terraform evaluates
// them as expressions in JSON files.
func writeTestOverride(t *testing.T, exampleDir string, moduleArgs map[string]any) {
	t.Helper()

	cluster := map[string]any{
		// The endpoint public access and the admin permissions are enabled so
		// the tests can run k8s commands against the cluster, regardless of the
		// values set in the examples.
		"endpoint_public_access":                   true,
		"enable_cluster_creator_admin_permissions": true,
		// Make sure to skip final backup to allow a flawless destroy when running
		// the tests
		"fsx_openzfs_skip_final_backup":               true,
		"fsx_openzfs_delete_child_volumes_on_destroy": true,
	}
	maps.Copy(cluster, moduleArgs)

	overrides := map[string]any{
		"module": map[string]any{
			"cluster": cluster,
		},
	}

	data, err := json.MarshalIndent(overrides, "", "  ")
	if err != nil {
		t.Fatalf("failed to marshal test override: %v", err)
	}

	dst := filepath.Join(exampleDir, "test_override.tf.json")
	if err := os.WriteFile(dst, data, 0600); err != nil {
		t.Fatalf("failed to write test override: %v", err)
	}
}

// configureKubectl sets up a dedicated kubeconfig for the deployed cluster.
func configureKubectl(t *testing.T, terraformOptions *terraform.Options) *k8s.KubectlOptions {
	t.Helper()

	kubeconfigCmd := terraform.Output(t, terraformOptions, "kubeconfig_command")
	kubeconfigPath := filepath.Join(t.TempDir(), "kubeconfig")
	shell.RunCommand(t, shell.Command{
		Command: "bash",
		Args:    []string{"-c", kubeconfigCmd + " --kubeconfig " + kubeconfigPath},
	})

	return k8s.NewKubectlOptions("", kubeconfigPath, "default")
}

// testEBSCSIDriver validates that the EBS CSI driver addon is functional by creating a PVC
// and a Pod that mounts it. The Pod should reach the Ready state if things are working.
func testEBSCSIDriver(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	t.Helper()

	fixturesDir, _ := filepath.Abs("fixtures/ebs-csi")
	scPath := filepath.Join(fixturesDir, "storageclass.yaml")
	pvcPath := filepath.Join(fixturesDir, "pvc.yaml")
	podPath := filepath.Join(fixturesDir, "pod.yaml")

	namespace := "ebs-csi-test"

	k8s.CreateNamespace(t, kubectlOptions, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)

	nsOptions := k8s.NewKubectlOptions(kubectlOptions.ContextName, kubectlOptions.ConfigPath, namespace)

	// StorageClass is cluster-scoped, so use the default kubectlOptions
	k8s.KubectlApply(t, kubectlOptions, scPath)
	defer k8s.KubectlDelete(t, kubectlOptions, scPath)

	// PVC and Pod are namespace-scoped
	k8s.KubectlApply(t, nsOptions, pvcPath)
	k8s.KubectlApply(t, nsOptions, podPath)

	// Wait for the PVC to be bound, confirming EBS volume provisioning
	bound := corev1.ClaimBound
	k8s.WaitUntilPersistentVolumeClaimInStatus(t, nsOptions, "ebs-csi-test-pvc", &bound, waitRetries, waitInterval)

	// Wait for the pod to be ready, confirming volume attachment and mount
	k8s.WaitUntilPodAvailable(t, nsOptions, "ebs-csi-test-pod", waitRetries, waitInterval)
}

// testFSxOpenZFSOutputs validates that the FSx for OpenZFS outputs consumers rely on are
// populated. A successful apply already means the filesystem reached AVAILABLE, so this
// catches outputs wired to null or to the wrong attribute.
func testFSxOpenZFSOutputs(t *testing.T, terraformOptions *terraform.Options) {
	t.Helper()

	prefixes := map[string]string{
		"fsx_openzfs_id":                  "fs-",
		"fsx_openzfs_root_volume_id":      "fsvol-",
		"fsx_openzfs_csi_driver_role_arn": "arn:",
	}

	for output, prefix := range prefixes {
		value := terraform.Output(t, terraformOptions, output)
		if !strings.HasPrefix(value, prefix) {
			t.Errorf("output %s = %q, want a value starting with %q", output, value, prefix)
		}
	}
}

// testSinglePrivateSubnet validates that the nodes got exactly one private subnet. With
// a created single-AZ VPC, this means the control-plane-only subnet stayed out of the
// node subnets.
func testSinglePrivateSubnet(t *testing.T, terraformOptions *terraform.Options) {
	t.Helper()

	subnets := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	if len(subnets) != 1 {
		t.Errorf("output private_subnet_ids = %v, want exactly one subnet", subnets)
	}
}

// runExample deploys an example with moduleArgs applied to its cluster module, runs the
// checks that apply to every example, and destroys it. Each run works on its own copy
// of the repo, so two runs of the same example can't overwrite each other's override
// file, .terraform directory or state. The copy is kept after the test, so its state
// can be used to clean up by hand if the destroy fails.
//
// namePrefix is part of project_name, which ends up in IAM role name prefixes that AWS
// limits to 38 characters. Keep it at 14 characters or fewer.
func runExample(t *testing.T, example string, namePrefix string, moduleArgs map[string]any) *terraform.Options {
	t.Helper()

	exampleFolder := test_structure.CopyTerraformFolderToTemp(t, "..", filepath.Join("examples", example))
	writeTestOverride(t, exampleFolder, moduleArgs)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    exampleFolder,
		TerraformBinary: "tofu",
		Vars: map[string]any{
			"project_name": namePrefix + random.UniqueId(),
		},
	})

	// Make sure to destroy resources at the end of the test, regardless of whether the test passes or fails
	t.Cleanup(func() { terraform.Destroy(t, terraformOptions) })

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)

	kubectlOptions := configureKubectl(t, terraformOptions)

	t.Run("ebs_csi_driver", func(t *testing.T) {
		testEBSCSIDriver(t, kubectlOptions)
	})

	t.Run("fsx_openzfs_outputs", func(t *testing.T) {
		testFSxOpenZFSOutputs(t, terraformOptions)
	})

	return terraformOptions
}

func TestExampleComplete(t *testing.T) {
	t.Parallel()

	runExample(t, "complete", "test-complete-", nil)
}

// TestExampleCompleteSingleAZ runs the complete example with its nodes in one AZ. The
// module adds a private subnet in a second AZ for the control plane only.
func TestExampleCompleteSingleAZ(t *testing.T) {
	t.Parallel()

	terraformOptions := runExample(t, "complete", "test-saz-cmpl-", map[string]any{
		"availability_zones": []string{"us-west-2a"},
		// MULTI_AZ_1 needs subnets in two AZs.
		"fsx_openzfs_deployment_type": "SINGLE_AZ_2",
	})

	t.Run("single_private_subnet", func(t *testing.T) {
		testSinglePrivateSubnet(t, terraformOptions)
	})
}

func TestExampleExistingResources(t *testing.T) {
	t.Parallel()

	runExample(t, "existing-resources", "test-existing-", nil)
}

// TestExampleExistingResourcesSingleAZ runs the existing-resources example with its
// nodes on the first of the example's private subnets and the control plane on the
// first two, which are in different AZs.
func TestExampleExistingResourcesSingleAZ(t *testing.T) {
	t.Parallel()

	runExample(t, "existing-resources", "test-saz-exst-", map[string]any{
		"existing_private_subnet_ids":       []string{"${aws_subnet.private[0].id}"},
		"existing_control_plane_subnet_ids": []string{"${aws_subnet.private[0].id}", "${aws_subnet.private[1].id}"},
	})
}
