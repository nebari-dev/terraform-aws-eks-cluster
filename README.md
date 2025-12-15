# Terraform Module Template

A comprehensive template repository for creating Terraform/OpenTofu modules with best practices, automated testing, and CI/CD workflows.

## Features

- 🏗️ **OpenTofu/Terraform Support**: Compatible with both OpenTofu and Terraform
- ✅ **Automated Testing**: Terratest integration with Go-based tests
- 📚 **Auto-Documentation**: terraform-docs integration with pre-commit hooks
- 🔍 **Code Quality**: Pre-commit hooks with formatting, validation, and linting
- 🚀 **CI/CD Pipeline**: GitHub Actions for testing and publishing
- 📁 **Example Configurations**: Dev and prod example implementations
- 🛡️ **Security Scanning**: Trivy integration for configuration security

## Quick Start

1. **Use this template** by clicking "Use this template" on GitHub
2. **Clone your new repository**
3. **Customize** the module files for your specific use case
4. **Update** the testing configuration and examples
5. **Configure** GitHub Actions secrets for CI/CD

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml    # CI/CD pipeline
├── .pre-commit-config.yaml  # Pre-commit hook configuration
├── .terraform-docs.yml      # Terraform docs configuration
├── .tflint.hcl             # TFLint configuration
├── examples/               # Usage examples
│   ├── dev/               # Development environment example
│   └── prod/              # Production environment example
├── test/                  # Terratest suite
│   ├── go.mod            # Go module definition
│   └── module_test.go    # Test implementation
├── Makefile              # Development commands
├── main.tf               # Main module configuration (to be created)
├── variables.tf          # Input variables (to be created)
├── outputs.tf            # Output definitions (to be created)
├── versions.tf           # Provider version constraints (to be created)
└── README.md            # This file
```

## Module Documentation

The following section contains auto-generated documentation for this Terraform module using terraform-docs:

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

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |

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

## Documentation Maintenance

This README uses terraform-docs to automatically generate and maintain module documentation. The content between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` is automatically generated.

### How to Update Documentation

1. **Auto-generate**: Run `make docs` to update the terraform-docs section
2. **Manual content**: Edit sections outside the terraform-docs markers
3. **Configuration**: Modify `.terraform-docs.yml` to customize the generated content

### terraform-docs Workflow

- The `make docs` command uses Docker to run terraform-docs
- It reads your Terraform files (main.tf, variables.tf, outputs.tf, etc.)
- Generates documentation in Markdown format
- Injects the content between the `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers
- Preserves all custom content outside these markers

**Important**: Never manually edit content between the terraform-docs markers as it will be overwritten.

## Testing

This template includes comprehensive testing setup using Terratest. The tests validate:
- Infrastructure provisioning
- Resource configuration
- Input validation
- Multi-environment scenarios

### Test Structure

The template includes three types of tests:

1. **Terraform Validation**: Tests that the main module can be initialized and validated
2. **Examples Validation**: Tests that example configurations are syntactically correct
3. **Module Functionality**: Placeholder tests that demonstrate assertion patterns

**Note**: These are validation-only tests that don't deploy actual infrastructure. When developing your module, replace the placeholder tests with actual functionality tests as needed.

### Running Tests

```bash
# Run all tests
make test

# Run specific test functions
cd test && go test -v -run TestDevExample
```

## Makefile Commands

| Command       | Description                                      |
| ------------- | ------------------------------------------------ |
| `make help`   | Display available make targets with descriptions |
| `make init`   | Initialize OpenTofu and install pre-commit hooks |
| `make fmt`    | Format all Terraform files                      |
| `make validate` | Validate Terraform configuration              |
| `make lint`   | Run all linting checks                          |
| `make test`   | Run the full test suite                         |
| `make docs`   | Generate documentation with terraform-docs      |
| `make clean`  | Clean up temporary files and directories        |
