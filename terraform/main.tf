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
      source  = "azure/azapi"
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
  tags     = local.tags
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
  name                         = "${local.func_name}-ondemand"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  replica_timeout_in_seconds = 60
  replica_retry_limit        = 10
  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }
  template {
    container {
      image = "ghcr.io/implodingduck/aca-jobs-ondemand:latest"
      name  = "ondemand"

      cpu    = 0.5
      memory = "1Gi"
    }
  }
  workload_profile_name = "Consumption"
  tags                  = local.tags
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
  name                         = "${local.func_name}-queue-manual"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  replica_timeout_in_seconds = 60
  replica_retry_limit        = 10
  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }
  template {
    container {
      image = "ghcr.io/implodingduck/aca-jobs-queue:latest"
      name  = "queue"
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
        name  = "SERVICEBUS_FULLY_QUALIFIED_NAMESPACE"
        value = "${data.azurerm_servicebus_namespace.example.name}.servicebus.windows.net"
      }

      cpu    = 0.5
      memory = "1Gi"
    }
  }
  workload_profile_name = "Consumption"
  tags                  = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }
}

resource "azapi_resource" "queue" {
  type      = "Microsoft.App/jobs@2025-02-02-preview"
  name      = "${local.func_name}-queue"
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

  schema_validation_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }
  tags = local.tags
  body = {
    properties = {

      environmentId = azurerm_container_app_environment.this.id
      template = {
        containers = [
          {
            image = "ghcr.io/implodingduck/aca-jobs-queue:latest"
            name  = "queue"
            env = [
              {
                name  = "AZURE_SUBSCRIPTION_ID"
                value = data.azurerm_client_config.current.subscription_id
              },
              {
                name  = "AZURE_TENANT_ID"
                value = data.azurerm_client_config.current.tenant_id
              },
              {
                name  = "AZURE_CLIENT_ID"
                value = azurerm_user_assigned_identity.aca.client_id
              },
              {
                name  = "SERVICE_BUS_QUEUE_NAME"
                value = "deathstarstatus"
              },
              {
                name  = "SERVICEBUS_FULLY_QUALIFIED_NAMESPACE"
                value = "${data.azurerm_servicebus_namespace.example.name}.servicebus.windows.net"
              }
            ]
            resources = {
              cpu    = 0.5
              memory = "1Gi"
            }
          }
        ]
      }



      configuration = {
        triggerType = "Event"
        replicaTimeout = 60
        replicaRetryLimit       = 10
        
        eventTriggerConfig = {
          scale = {
            parallelism            = 1
            replicaCompletionCount = 1
            rules = [
              {
                name = "queue-trigger"
                type = "azure-servicebus"
                metadata = {
                  queueName = "deathstarstatus"
                  namespace = "${data.azurerm_servicebus_namespace.example.name}"
                }
                identity = azurerm_user_assigned_identity.aca.id
              }
            ]
          }
        }
        scheduleTriggerConfig = null
        manualTriggerConfig = null
      }
      workloadProfileName = "Consumption"

    }
  }
}


resource azurerm_storage_account "storage" {
  name                     = "st${local.func_name}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false

  tags = local.tags

}

resource "azurerm_storage_queue" "queue" {
  name                 = "mysamplequeue"
  storage_account_name = azurerm_storage_account.storage.name
}

resource "azapi_resource" "storagequeue" {
  type      = "Microsoft.App/jobs@2025-02-02-preview"
  name      = "${local.func_name}-storagequeue"
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

  schema_validation_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }
  tags = local.tags
  body = {
    properties = {

      environmentId = azurerm_container_app_environment.this.id
      template = {
        containers = [
          {
            image = "ghcr.io/implodingduck/aca-jobs-storagequeue:latest"
            name  = "queue"
            env = [
              {
                name  = "AZURE_SUBSCRIPTION_ID"
                value = data.azurerm_client_config.current.subscription_id
              },
              {
                name  = "AZURE_TENANT_ID"
                value = data.azurerm_client_config.current.tenant_id
              },
              {
                name  = "AZURE_CLIENT_ID"
                value = azurerm_user_assigned_identity.aca.client_id
              },
              {
                name  = "QUEUE_NAME"
                value = "mysamplequeue"
              },
              {
                name  = "ACCOUNT_URL"
                value = "https://${azurerm_storage_account.storage.name}.queue.core.windows.net"
              }
            ]
            resources = {
              cpu    = 0.5
              memory = "1Gi"
            }
          }
        ]
      }



      configuration = {
        triggerType = "Event"
        replicaTimeout = 60
        replicaRetryLimit       = 10
        
        eventTriggerConfig = {
          scale = {
            parallelism            = 1
            replicaCompletionCount = 1
            rules = [
              {
                name = "queue-trigger"
                type = "azure-queue"
                metadata = {
                  queueName = "mysamplequeue"
                  accountName = "${azurerm_storage_account.storage.name}"
                }
                identity = azurerm_user_assigned_identity.aca.id
              }
            ]
          }
        }
        scheduleTriggerConfig = null
        manualTriggerConfig = null
      }
      workloadProfileName = "Consumption"

    }
  }
}