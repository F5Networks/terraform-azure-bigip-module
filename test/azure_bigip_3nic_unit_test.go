package test

import (
	"crypto/tls"
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformAzure3NicExample(t *testing.T) {
	t.Parallel()
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/bigip_azure_3nic_deploy",
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
	assert.Equal(t, 443, mgmtPort[0])
	// assert.Equal(t, "443", fmt.Sprintf("%d", mgmtPort[0]))
	assert.NotEqual(t, "", mgmtPublicURL[0])

	logger.Logf(t, "mgmtPublicURL:%+v", mgmtPublicURL)
	// logger.Logf(t, "bigipPassword:%+v",bigipPassword)
	testUrl := fmt.Sprintf("https://%s:%s@%s:%d/mgmt/shared/appsvcs/info", string(bigipUsername[0]), string(bigipPassword[0]), string(mgmtPublicIP[0]), int(mgmtPort[0]))

	// testUrl := fmt.Sprintf("https://%s:%s@%s:%d/mgmt/shared/appsvcs/info", bigipUsername[0], bigipPassword[0], mgmtPublicIP[0], mgmtPort[0])
	logger.Logf(t, "testUrl:%+v", testUrl)
	// fmt.Sprintf("https://%s:%s@%s:%s/mgmt/shared/appsvcs/info", string([]byte{bigipUsername[0]}), string([]byte{bigipPassword[0]}), string([]byte{mgmtPublicIP[0]}), string([]byte{mgmtPort[0]})),

	// Setup a TLS configuration to submit with the helper, a blank struct is acceptable
	tlsConfig := tls.Config{}

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		testUrl,
		&tlsConfig,
		20,
		10*time.Second,
		func(statusCode int, body string) bool {
			return statusCode == 200
		},
	)

}
