provider "azurerm" {}

resource "random_string" "password" {
  length = 24
  special = true
  override_special = "/?\" "
}

#Need a postgres
variable "psql_storage" {
  default = ""
}
variable "crm-resource_group_name" {
  default = ""
}
resource "azurerm_postgresql_server" "psql_db" {
  name                = "postgresql-server-cliient1"
  location            = "west-europe"
  resource_group_name = var.crm-resource_group_name

  sku {
    name     = "GP_Gen5_2"
    capacity = 2
    tier     = "GeneralPurpose"
    family   = 10240
  }

  storage_profile {
    storage_mb            = var.psql_storage
    backup_retention_days = 7
    geo_redundant_backup  = "Enabled"
    auto_grow             = "Enabled"
  }

  administrator_login          = "cliient1psqlmanager"
  administrator_login_password = random_string.password.result
  version                      = "10.0"
  ssl_enforcement              = "Enabled"

  tags = {
    Product = "CRM"
    environment = "Production"
    type = "database"
    resource = "postgres"
    client = "cliient1"
    Terraform   = "true"
  }
}

variable "kubernetes_subnet_ids" {
  type = "list"
}
resource "azurerm_postgresql_virtual_network_rule" "psql_db_net_admin" {
  count = length(var.kubernetes_subnet_ids)
  name                                 = "postgresql-rule-admin-${count.index}"
  resource_group_name                  = var.crm-resource_group_name
  server_name                          = azurerm_postgresql_server.psql_db.name
  subnet_id                            = var.kubernetes_subnet_ids[count.index]
  ignore_missing_vnet_service_endpoint = true
}

variable "onprem_acl_list" {
  type = "list"
}
resource "azurerm_postgresql_firewall_rule" "office1" {
  count = length(var.onprem_acl_list)
  name                = "office${count.index}"
  resource_group_name = var.crm-resource_group_name
  server_name         = azurerm_postgresql_server.psql_db.name
  start_ip_address    = var.onprem_acl_list[count.index]
  end_ip_address      = var.onprem_acl_list[count.index]
}

resource "azurerm_postgresql_firewall_rule" "azure" {
  name                = "azureServices"
  resource_group_name = var.crm-resource_group_name
  server_name         = azurerm_postgresql_server.psql_db.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


#Configuring CRM CDN endpoints and storage web delivery
resource "azurerm_storage_container" "crm-admin" {
  name                  = "client1-admin"
  storage_account_name  = "cdnclient1"
  container_access_type = "blob"
}

resource "azurerm_storage_container" "crm-member" {
  name                  = "client1-member"
  storage_account_name  = "cdnclient1"
  container_access_type = "blob"
}

variable "cdn_profile_name" {}

variable "cdn_resource_group_name" {}

data "azurerm_cdn_profile" "cdnprofile" {
  name= var.cdn_profile_name
  resource_group_name = var.cdn_resource_group_name
}

data "azurerm_storage_account" "cdn-storage" {
  name = "mywebdelivery"
  resource_group_name = var.cdn_resource_group_name
}

locals {
  cdn-primary-blob-endpoint = data.azurerm_storage_account.cdn-storage.primary_blob_endpoint
}

locals {
  host-primary-blob = replace(replace(local.cdn-primary-blob-endpoint,"https://",""),"/","")
}


resource "azurerm_cdn_endpoint" "admin-cdn-endpoint" {
  location = "northeurope"
  resource_group_name   = var.cdn_resource_group_name
  profile_name = var.cdn_profile_name
  name = "client1-impact-crm-admin"

  origin {
    host_name = local.host-primary-blob
    name = "client1-admin-crm-${cdnclient1}"
  }
  origin_path = "/${azurerm_storage_container.crm-admin.name}/"
  origin_host_header = local.host-primary-blob
  is_http_allowed = true
  is_https_allowed = true
  is_compression_enabled = false
  querystring_caching_behaviour = "NotSet"

  optimization_type = "GeneralWebDelivery"
}

variable "subscription_id" {
  default = "aaaaaaa-bbb-ccccc-ccc-dddddddd"
}

resource "null_resource" "admin-azure-cdn-rules" {
  provisioner "local-exec" {
    command =  "az cdn endpoint rule add --resource-group ${var.cdn_resource_group_name} --profile-name ${var.cdn_profile_name} --name ${azurerm_cdn_endpoint.admin-cdn-endpoint.name} --order 1 --rule-name RedirectToHTTPS --match-variable RequestScheme  --operator Equal --match-values HTTP --action-name UrlRedirect --redirect-protocol Https --redirect-type Found --subscription ${var.subscription_id}"
  }
  depends_on = [azurerm_cdn_endpoint.admin-cdn-endpoint]
}

resource "null_resource" "admin-azure-cdn-rules1" {
  provisioner "local-exec" {
    command = "az cdn endpoint rule add --resource-group ${var.cdn_resource_group_name} --profile-name ${var.cdn_profile_name} --name ${azurerm_cdn_endpoint.admin-cdn-endpoint.name} --rule-name AngularRewrite --order 2 --action-name UrlRewrite --destination '/index.html' --source-pattern '/' --preserve-unmatched-path false  --match-values 1 --negate-condition false --operator 'LessThan' --match-variable 'UrlFileExtension' --subscription ${var.subscription_id}"
  }
  depends_on = [null_resource.admin-azure-cdn-rules]
}

resource "azurerm_cdn_endpoint" "member-cdn-endpoint" {
  location = "northeurope"
  resource_group_name   = var.cdn_resource_group_name
  profile_name = var.cdn_profile_name
  name = "client1-impact-crm-member"

  origin {
    host_name = local.host-primary-blob
    name = "client1-member-crm-${cdnclient1}"
  }

  origin_path = "/${azurerm_storage_container.crm-member.name}/"
  origin_host_header = local.host-primary-blob
  is_http_allowed = true
  is_https_allowed = true
  is_compression_enabled = false
  querystring_caching_behaviour = "NotSet"

  optimization_type = "GeneralWebDelivery"
}

resource "null_resource" "member-azure-cdn-rules" {
  provisioner "local-exec" {
    command =  "az cdn endpoint rule add --resource-group ${var.cdn_resource_group_name} --profile-name ${var.cdn_profile_name} --name ${azurerm_cdn_endpoint.member-cdn-endpoint.name} --order 1 --rule-name RedirectToHTTPS --match-variable RequestScheme  --operator Equal --match-values HTTP --action-name UrlRedirect --redirect-protocol Https --redirect-type Found --subscription ${var.subscription_id}"
  }
  depends_on = [azurerm_cdn_endpoint.member-cdn-endpoint]
}

resource "null_resource" "member-azure-cdn-rules1" {
  provisioner "local-exec" {
    command = "az cdn endpoint rule add --resource-group ${var.cdn_resource_group_name} --profile-name ${var.cdn_profile_name} --name ${azurerm_cdn_endpoint.member-cdn-endpoint.name} --rule-name AngularRewrite --order 2 --action-name UrlRewrite --destination '/index.html' --source-pattern '/' --preserve-unmatched-path false  --match-values 1 --negate-condition false --operator 'LessThan' --match-variable 'UrlFileExtension' --subscription ${var.subscription_id}"
  }
  depends_on = [null_resource.member-azure-cdn-rules]
}
