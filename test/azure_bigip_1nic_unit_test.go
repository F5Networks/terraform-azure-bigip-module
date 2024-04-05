package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformAzure1NicExample(t *testing.T) {
	t.Parallel()
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/bigip_azure_1nic_deploy",
		Vars: map[string]interface{}{
			"location": "eastus",
		},
	}
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
	mgmtPublicIP := terraform.Output(t, terraformOptions, "mgmtPublicIP")
	bigipPassword := terraform.Output(t, terraformOptions, "bigip_password")
	bigipUsername := terraform.Output(t, terraformOptions, "bigip_username")
	mgmtPort := terraform.Output(t, terraformOptions, "mgmtPort")
	mgmtPublicURL := terraform.Output(t, terraformOptions, "mgmtPublicURL")

	assert.NotEqual(t, "", mgmtPublicIP[0])
	assert.NotEqual(t, "", bigipPassword[0])
	assert.NotEqual(t, "", bigipUsername[0])
	assert.Equal(t, 8443, mgmtPort[0])
	// assert.Equal(t, "8443", fmt.Sprintf("%d", mgmtPort[0]))
	assert.NotEqual(t, "", mgmtPublicURL[0])

}
