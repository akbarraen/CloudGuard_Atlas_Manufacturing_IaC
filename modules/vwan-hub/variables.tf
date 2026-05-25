variable "vwan_name" { type = string }
variable "hub_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "hub_address_prefix" { type = string }
variable "tags" { type = map(string) ; default = {} }
