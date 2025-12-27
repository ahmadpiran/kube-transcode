terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
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
  name                      = "kube-transcode-aks"
  location                  = azurerm_resource_group.kube_transcode_rg.location
  resource_group_name       = azurerm_resource_group.kube_transcode_rg.name
  dns_prefix                = "kubetranscode"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

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

resource "azurerm_storage_account" "storage" {
  name                     = "ktstor${random_id.suffix.hex}" # Must be globally unique
  resource_group_name      = azurerm_resource_group.kube_transcode_rg.name
  location                 = azurerm_resource_group.kube_transcode_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "fshare" {
  name                 = "transcode-share"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 5 # 5GB
}

# Create managed identity for the Go app
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "kube-transcode-identity"
  location            = azurerm_resource_group.kube_transcode_rg.location
  resource_group_name = azurerm_resource_group.kube_transcode_rg.name
}

# Grant permission to storage account
resource "azurerm_role_assignment" "storage_role" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# Creating federated indentity credential, for linking K8s ServiceAccount to the Azure Identity
resource "azurerm_federated_identity_credential" "fed_identity" {
  name                = "kube-transcode-fed"
  resource_group_name = azurerm_resource_group.kube_transcode_rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.app_identity.id
  subject             = "system:serviceaccount:default:kube-transcode-sa"
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "resource_group_name" {
  value = azurerm_resource_group.kube_transcode_rg.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "client_id" {
  value = azurerm_user_assigned_identity.app_identity.client_id
}