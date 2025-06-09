terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.22.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "azure/azapi"
      version = "=2.3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-${local.loc_short}"
  resource_group_name = "DefaultResourceGroup-${local.loc_short}"
} 

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags = local.tags
}

# resource "azurerm_servicebus_namespace" "this" {
#   name                = "sbn-${local.func_name}"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   sku                 = "Standard"

#   tags = local.tags
# }

# resource "azurerm_servicebus_queue" "this" {
#   name         = "deathstarstatus"
#   namespace_id = azurerm_servicebus_namespace.this.id

#   partitioning_enabled = true
# }


resource "azurerm_container_app_environment" "this" {
  name                       = "ace-${local.func_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }


  tags = local.tags

  lifecycle {
    ignore_changes = [
      log_analytics_workspace_id,
    ]
  }

}

resource "azurerm_container_app_job" "ondemand" {
  name = "${local.func_name}-ondemand"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  replica_timeout_in_seconds = 60
  replica_retry_limit = 10
  manual_trigger_config {
    parallelism = 1
    replica_completion_count = 1
  }
  template {
    container {
      image = "ghcr.io/implodingduck/aca-jobs-ondemand:latest"
      name = "ondemand"
      
      cpu    = 0.5
      memory = "1Gi"
    }
  }
  workload_profile_name = "Consumption"
  tags = local.tags
}


data "azurerm_servicebus_namespace" "example" {
  name                = var.sbn
  resource_group_name = var.sbn_rg
}


resource "azurerm_user_assigned_identity" "aca" {
  location            = azurerm_resource_group.rg.location
  name                = "uai-${local.func_name}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "app_gateway_secrets" {
  scope                = data.azurerm_servicebus_namespace.example.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}


resource "azurerm_container_app_job" "queue" {
  name = "${local.func_name}-queue"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  replica_timeout_in_seconds = 60
  replica_retry_limit = 10
  manual_trigger_config {
    parallelism = 1
    replica_completion_count = 1
  }
  template {
    container {
      image = "ghcr.io/implodingduck/aca-jobs-queue:latest"
      name = "queue"
      env {
        name  = "AZURE_SUBSCRIPTION_ID"
        value = data.azurerm_client_config.current.subscription_id
      }
      env {
        name  = "AZURE_TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.aca.client_id
      }
      
      env {
        name  = "SERVICE_BUS_QUEUE_NAME"
        value = "deathstarstatus"
      }

      env {
        name = "SERVICEBUS_FULLY_QUALIFIED_NAMESPACE"
        value = data.azurerm_servicebus_namespace.example.endpoint
      }
      env {
        name = "APPSETTING_WEBSITE_SITE_NAME"
        value = "${local.func_name}-queue"
      }

      cpu    = 0.5
      memory = "1Gi"
    }
  }
  workload_profile_name = "Consumption"
  tags = local.tags

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }

}