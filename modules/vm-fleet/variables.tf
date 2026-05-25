variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vms" { type = list(object({ name = string ; size = string ; os = string ; subnet_id = string ; tags = map(string) })) }
variable "tags" { type = map(string) ; default = {} }
