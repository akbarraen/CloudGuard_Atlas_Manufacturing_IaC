variable "subscription_id" { type = string }
variable "location" { default = "westeurope" }
variable "location_short" { default = "weu" }
variable "virtual_hub_id" { type = string }
variable "firewall_private_ip" { type = string }
variable "tags" { default = { company = "ManufacturingCorp" ; env = "backend" ; managed_by = "Terraform" } }
