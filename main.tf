data "azurerm_resource_group" "rg" {
  name     = var.rg
}

data "azurerm_user_assigned_identity" "mgmtidentity" {
      name                = "MI-AVDAMA-PROD"
      resource_group_name = "avdmgmtrg"
  }

resource "azurerm_virtual_desktop_host_pool" "hp" {
    custom_rdp_properties    = "usemultimon:i:0;drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:0;redirectsmartcards:i:1;usbdevicestoredirect:s:;enablecredsspsupport:i:1;maximizetocurrentdisplays:i:0;screen mode id:i:0"
    description              = "Created through the Azure Virtual Desktop extension"
    load_balancer_type       = "BreadthFirst"
    location                 = "westeurope"
    maximum_sessions_allowed = 11
    name                     = "HP-STD-Win11-sap-EAS"
    preferred_app_group_type = "RailApplications"
    resource_group_name      = "avdazhprgeas"
    start_vm_on_connect      = "${var.bol}"
    tags                     = {
        "AVDAZServices" = "AVD Components"
    }
    type                     = "Pooled"
    validate_environment     = false

    timeouts {}
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avd_token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hp.id
  expiration_date = var.rfc3339
}


data "azurerm_key_vault" "key_vault" {
  name                = "avdazkeymgt"
  resource_group_name = "avdmgmtrg"
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = "avdadministrator"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}
output "admin_password" {
  value     = data.azurerm_key_vault_secret.admin_password.value
  sensitive = true
}


data "azurerm_key_vault_secret" "domain_password" {
  name         = "DomainAccount"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}
output "domain_password" {
  value     = data.azurerm_key_vault_secret.domain_password.value
  sensitive = true
}

data "azurerm_subnet" "vm_subnet" {
  name                 = "vnsazeapsoeki002avddesktop"
  virtual_network_name = "vneazeapsoek002azurevirtdesk"
  resource_group_name  = "Default-Networking"
}

data "azurerm_shared_image_version" "image" {
name                = var.image_number
image_name          = "azure_windows_11_baseos_avd_sap800_23h2"
gallery_name        = "acgazweuavdprod02"
resource_group_name = "rgazweuavdprodacg01"
}

resource "azurerm_network_interface" "avd_vm_nic" {
  count               = var.rdsh_count
  name                = "${var.prefix}-${count.index + 1}-nic"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    data.azurerm_resource_group.rg
  ]
}

resource "azurerm_windows_virtual_machine" "avd_vm" {
  count                 = var.rdsh_count
  name                  = "${var.prefix}-${count.index + 1}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                  = var.vm_size
  network_interface_ids = ["${azurerm_network_interface.avd_vm_nic.*.id[count.index]}"]
  provision_vm_agent    = true
  admin_username = var.local_admin_username
  admin_password = data.azurerm_key_vault_secret.admin_password.value
  license_type="Windows_Client"
  identity {
        type = "UserAssigned"
        identity_ids = [data.azurerm_user_assigned_identity.mgmtidentity.id]
      }

  source_image_id = data.azurerm_shared_image_version.image.id

  os_disk {
    name                 = "${lower(var.prefix)}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  tags = {
    AVDAZServices : "AVD Components"
    AVDInfra : "Virtual Machine"
    excludeFromScaling : "excludeFromScaling"
  }
  zone = "${(count.index%3)+1}"

  depends_on = [
    data.azurerm_resource_group.rg,
    azurerm_network_interface.avd_vm_nic
  ]
}

resource "azurerm_virtual_machine_extension" "domain_join" {
  count                      = var.rdsh_count
  name                       = "${var.prefix}-${count.index + 1}-domainJoin"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "Name": "${var.domain_name}",
      "OUPath": "${var.ou_path}",
      "User": "${var.domain_user_upn}@${var.domain_name}",
      "Restart": "true",
      "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password":"${data.azurerm_key_vault_secret.domain_password.value}"
    }
PROTECTED_SETTINGS

   lifecycle {
   ignore_changes = [settings, protected_settings]
   }

}

resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  count              = var.rdsh_count
  name               = "${var.prefix}${count.index + 1}-avd_dsc"
  virtual_machine_id = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  depends_on = [
    azurerm_virtual_machine_extension.domain_join
  ]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "modulesUrl": "${var.artifactslocation}",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "HostPoolName": "azurerm_virtual_desktop_host_pool.hp.name"
      }
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "properties": {
      "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.avd_token.token}"
    }
  }
PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

resource "azurerm_virtual_machine_extension" "vmext_azuremon" {
  count              = var.rdsh_count
  name               = "${var.prefix}${count.index + 1}-avd_azuremon"
  virtual_machine_id = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

data "azurerm_monitor_data_collection_rule" "dcravd" {
  name                = "microsoft-avdi-eastasia"
  resource_group_name = "avdazhprgeas"
}
output "rule_id1" {
  value = data.azurerm_monitor_data_collection_rule.dcravd.id
}
resource "azurerm_monitor_data_collection_rule_association" "avd_dcra" {
 count                   = var.rdsh_count
 name                    = "${var.prefix}${count.index + 1}-avd_dcr"
 target_resource_id      = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
 data_collection_rule_id = data.azurerm_monitor_data_collection_rule.dcravd.id
}

