<!-- BEGIN_TF_DOCS -->


## Usage

```hcl
module "cloudrun_ai_app" {
  source  = "openteams-ai/cloudrun-ai-app/gcp"
  version = "~> 1.0"

  project_id     = "my-gcp-project"
  region         = "us-central1"
  customer_name  = "acme-corp"
  domain_name    = "acme.example.com"

  # Application configuration
  app_image      = "gcr.io/my-project/ai-app:latest"
  app_env_vars   = {
    AI_BACKEND_URL = "https://api.openai.com/v1"
    MCP_SERVER_URL = "https://mcp.example.com"
  }
}
```

## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
