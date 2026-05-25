resource "azurerm_network_interface" "nic" {
  for_each = { for vm in var.vms : vm.name => vm }
  name = "${each.value.name}-nic"
  resource_group_name = var.resource_group_name
  location = var.location
  tags = var.tags
  ip_configuration {
    name = "internal"
    subnet_id = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "win" {
  for_each = { for vm in var.vms : vm.name => vm if vm.os == "windows" }
  name = each.value.name
  resource_group_name = var.resource_group_name
  location = var.location
  size = each.value.size
  admin_username = "azureadmin"
  admin_password = "P@ssw0rdDemo1234!"
  tags = merge(var.tags, each.value.tags)
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  os_disk { caching = "ReadWrite" ; storage_account_type = "Premium_LRS" }
  source_image_reference { publisher = "MicrosoftWindowsServer" ; offer = "WindowsServer" ; sku = "2022-Datacenter" ; version = "latest" }
}
resource "azurerm_linux_virtual_machine" "lin" {
  for_each = { for vm in var.vms : vm.name => vm if vm.os == "linux" }
  name = each.value.name
  resource_group_name = var.resource_group_name
  location = var.location
  size = each.value.size
  admin_username = "azureadmin"
  admin_password = "P@ssw0rdDemo1234!"
  disable_password_authentication = false
  tags = merge(var.tags, each.value.tags)
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  os_disk { caching = "ReadWrite" ; storage_account_type = "Premium_LRS" }
  source_image_reference { publisher = "Canonical" ; offer = "0001-com-ubuntu-server-jammy" ; sku = "22_04-lts" ; version = "latest" }
}
