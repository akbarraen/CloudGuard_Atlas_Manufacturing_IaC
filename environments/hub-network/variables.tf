variable "hub_subscription_id" { type = string }
variable "location" { default = "westeurope" }
variable "location_short" { default = "weu" }
variable "tags" { default = { company = "ManufacturingCorp" ; env = "hub" ; managed_by = "Terraform" } }
