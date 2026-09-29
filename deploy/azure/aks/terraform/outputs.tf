output "resource_group_name" {
  value = azurerm_resource_group.typescale.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.typescale.name
}

output "aks_kubernetes_version" {
  value = azurerm_kubernetes_cluster.typescale.kubernetes_version
}

output "acr_login_server" {
  value = azurerm_container_registry.typescale.login_server
}

output "acr_id" {
  value = azurerm_container_registry.typescale.id
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.typescale.oidc_issuer_url
}

output "node_pool_autoscaling_bounds" {
  value = {
    min = azurerm_kubernetes_cluster.typescale.default_node_pool[0].min_count
    max = azurerm_kubernetes_cluster.typescale.default_node_pool[0].max_count
  }
}
