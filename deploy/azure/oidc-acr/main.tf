terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "random" {}

variable "location" {
  description = "Allowed region for the temporary ACR and identity resources."
  type        = string
  default     = "canadacentral"
}

variable "resource_group_name" {
  type    = string
  default = "rg-typescale-oidc"
}

variable "github_owner" {
  type    = string
  default = "KoushikPraneeth"
}

variable "github_repo" {
  type    = string
  default = "typescale-platform"
}

variable "github_owner_id" {
  type    = string
  default = "94680295"
}

variable "github_repository_id" {
  type    = string
  default = "1381368356"
}

variable "github_environment" {
  type    = string
  default = "azure-demo"
}

data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "acr_push" {
  name  = "AcrPush"
  scope = azurerm_container_registry.typescale.id
}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "typescale" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Project   = "TypeScale"
    Purpose   = "TemporaryOIDCACRBenchmark"
    Lifecycle = "DeleteAfterBenchmark"
  }
}

resource "azurerm_container_registry" "typescale" {
  name                = "typescale${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.typescale.name
  location            = azurerm_resource_group.typescale.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = azurerm_resource_group.typescale.tags
}

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "typescale-github-oidc"
  resource_group_name = azurerm_resource_group.typescale.name
  location            = azurerm_resource_group.typescale.location
  tags                = azurerm_resource_group.typescale.tags
}

resource "azurerm_federated_identity_credential" "github_environment" {
  name                      = "github-azure-demo"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repository_id}:environment:${var.github_environment}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "acr_push" {
  scope                            = azurerm_container_registry.typescale.id
  role_definition_id               = data.azurerm_role_definition.acr_push.id
  principal_id                     = azurerm_user_assigned_identity.github_actions.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

output "acr_name" {
  value = azurerm_container_registry.typescale.name
}

output "acr_login_server" {
  value = azurerm_container_registry.typescale.login_server
}

output "client_id" {
  description = "Non-secret client identifier for GitHub Actions OIDC."
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}
