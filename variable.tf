variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "network_vnet_cidr" {
  type        = string
  description = "The CIDR of the network VNET"
}

variable "public_subnet_cidr" {
  type        = string
  description = "The CIDR for the network subnet"
}

variable "private_subnet_cidr" {
  type        = string
  description = "The CIDR for the network subnet"
}
variable "virtual_network_name" {
  type = string
}

variable "public_subnet" {
  type = string
}

variable "private_subnet" {
  type = string
}

variable "public_ip" {
  type = string
}

variable "azurerm_linux_virtual_machine_size" {
  type = string
}

variable "linux_admin_username" {
  type        = string
  description = "Username for Virtual Machine administrator account"
}
variable "linux_admin_password" {
  type        = string
  description = "Password for Virtual Machine administrator account"
}

variable "lb_ip" {
  type = string
}