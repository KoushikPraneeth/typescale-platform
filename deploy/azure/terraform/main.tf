terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  description = "Dedicated short-lived TypeScale demo resource group."
  type        = string
  default     = "rg-typescale-terraform"
}

variable "container_location" {
  description = "Region for Container Apps; must be allowed by the subscription."
  type        = string
  default     = "canadacentral"
}

variable "redis_location" {
  description = "Region for Azure Managed Redis; must be allowed by the subscription."
  type        = string
  default     = "northcentralus"
}

variable "app_image" {
  description = "Immutable GHCR image digest already exercised in Azure."
  type        = string
  default     = "ghcr.io/koushikpraneeth/typescale@sha256:e1e703adcd2da1f293624d29ba5cec378fe875ef3caf411de4568cc3a0aed222"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.app_image))
    error_message = "app_image must be pinned to a sha256 digest."
  }
}

variable "redis_sku" {
  description = "Azure Managed Redis SKU. Balanced_B0 was used in the earlier temporary benchmark."
  type        = string
  default     = "Balanced_B0"
}

resource "azurerm_resource_group" "typescale" {
  name     = var.resource_group_name
  location = var.container_location
  tags = {
    Project   = "TypeScale"
    Purpose   = "TemporaryTerraformBenchmark"
    Lifecycle = "DeleteAfterBenchmark"
  }
}

resource "azurerm_container_app_environment" "typescale" {
  name                = "typescale-tf-env"
  location            = var.container_location
  resource_group_name = azurerm_resource_group.typescale.name
  # Omitting Log Analytics keeps this short-lived test on streamed logs only.
}

resource "azurerm_managed_redis" "typescale" {
  name                      = "typescale-tf-cache"
  resource_group_name       = azurerm_resource_group.typescale.name
  location                  = var.redis_location
  sku_name                  = var.redis_sku
  high_availability_enabled = false
  public_network_access     = "Enabled"

  default_database {
    access_keys_authentication_enabled = true
    client_protocol                    = "Encrypted"
    clustering_policy                  = "NoCluster"
    eviction_policy                    = "VolatileLRU"
  }
}

resource "azurerm_container_app" "typescale" {
  name                         = "typescale-tf"
  resource_group_name          = azurerm_resource_group.typescale.name
  container_app_environment_id = azurerm_container_app_environment.typescale.id
  revision_mode                = "Single"

  secret {
    name  = "redis-url"
    value = "rediss://:${azurerm_managed_redis.typescale.default_database[0].primary_access_key}@${azurerm_managed_redis.typescale.hostname}:${azurerm_managed_redis.typescale.default_database[0].port}/0"
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "typescale"
      image  = var.app_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "REDIS_URL"
        secret_name = "redis-url"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = azurerm_resource_group.typescale.tags
}

output "resource_group_name" {
  value = azurerm_resource_group.typescale.name
}

output "app_fqdn" {
  value = azurerm_container_app.typescale.latest_revision_fqdn
}

output "app_url" {
  value = "https://${azurerm_container_app.typescale.latest_revision_fqdn}"
}

output "redis_endpoint" {
  value = azurerm_managed_redis.typescale.hostname
}
