package test

import (
	"path/filepath"
	"testing"
	"time"

	corev1 "k8s.io/api/core/v1"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

const (
	waitRetries  = 30
	waitInterval = 10 * time.Second
)

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

	kubectlOptions := configureKubectl(t, terraformOptions)

	t.Run("ebs_csi_driver", func(t *testing.T) {
		testEBSCSIDriver(t, kubectlOptions)
	})
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

	kubectlOptions := configureKubectl(t, terraformOptions)

	t.Run("ebs_csi_driver", func(t *testing.T) {
		testEBSCSIDriver(t, kubectlOptions)
	})
}
