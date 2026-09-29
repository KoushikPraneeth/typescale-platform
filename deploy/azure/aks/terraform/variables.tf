variable "resource_group_name" {
  description = "Dedicated, short-lived AKS lab resource group."
  type        = string
  default     = "rg-typescale-aks-demo"
}

variable "location" {
  description = "Azure region allowed by the active Student subscription."
  type        = string
  default     = "canadacentral"
}

variable "cluster_name" {
  description = "Name of the temporary AKS cluster."
  type        = string
  default     = "typescale-aks-demo"
}

variable "dns_prefix" {
  description = "Unique DNS prefix for the public AKS API endpoint."
  type        = string
  default     = "typescale-aks-20260929"
}

variable "acr_name" {
  description = "Globally unique 5-50 character lowercase alphanumeric ACR name. Check availability before apply."
  type        = string

  validation {
    condition     = length(var.acr_name) >= 5 && length(var.acr_name) <= 50 && can(regex("^[a-z0-9]+$", var.acr_name))
    error_message = "acr_name must be 5-50 lowercase letters or digits (ACR global naming rules)."
  }
}

variable "kubernetes_version" {
  description = "An AKS Kubernetes version currently offered in the selected region; verify with az aks get-versions before apply."
  type        = string
}

variable "admin_source_cidr" {
  description = "Current operator's public IPv4 egress address in /32 CIDR form; restricts the AKS API server."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_source_cidr, 0)) && can(regex("/32$", var.admin_source_cidr))
    error_message = "admin_source_cidr must be a valid IPv4 /32 address range."
  }
}

variable "node_vm_size" {
  description = "Single initial AKS node size; verify Student subscription quota and regional availability before apply."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "ssh_public_key_path" {
  description = "Path to an existing SSH public key (public key only; never provide a private key)."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
