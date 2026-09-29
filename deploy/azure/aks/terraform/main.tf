terraform {
  required_version = ">= 1.6.0"

  backend "local" {}

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

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "typescale" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project     = "TypeScale"
    Purpose     = "AKSValidation"
    Environment = "TemporaryDemo"
    Cleanup     = "DeleteAfterDemo"
  }
}

resource "azurerm_container_registry" "typescale" {
  name                          = var.acr_name
  resource_group_name           = azurerm_resource_group.typescale.name
  location                      = azurerm_resource_group.typescale.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  anonymous_pull_enabled        = false
  tags                          = azurerm_resource_group.typescale.tags
}

resource "azurerm_kubernetes_cluster" "typescale" {
  name                = var.cluster_name
  location            = azurerm_resource_group.typescale.location
  resource_group_name = azurerm_resource_group.typescale.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  local_account_disabled    = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.node_vm_size
    node_count                   = 1
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 2
    max_pods                     = 30
    only_critical_addons_enabled = false
    os_disk_size_gb              = 64
    os_disk_type                 = "Managed"
    type                         = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "azureuser"

    ssh_key {
      key_data = trimspace(file(pathexpand(var.ssh_public_key_path)))
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  api_server_access_profile {
    authorized_ip_ranges = [var.admin_source_cidr]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  tags = azurerm_resource_group.typescale.tags
}

# AKS nodes pull the app image from ACR with their managed kubelet identity.
# The ACR admin account remains disabled; no registry password is created.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.typescale.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.typescale.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

# Grant the signed-in deployer user credentials and cluster-scoped Kubernetes RBAC.
# Azure resource permissions alone do not grant Kubernetes API access.
resource "azurerm_role_assignment" "cluster_user" {
  scope                = azurerm_kubernetes_cluster.typescale.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "cluster_admin" {
  scope                = azurerm_kubernetes_cluster.typescale.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}
