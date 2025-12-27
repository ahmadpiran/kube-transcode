terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "kube_transcode_rg" {
  name     = "kube-transcode-rg"
  location = "francecentral"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "kube-transcode-aks"
  location            = azurerm_resource_group.kube_transcode_rg.location
  resource_group_name = azurerm_resource_group.kube_transcode_rg.name
  dns_prefix          = "kubetranscode"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2AS_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Dev"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.kube_transcode_rg.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}
