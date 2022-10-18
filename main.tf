# Configure the Azure provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.24.0"
    }
  }
}

provider "azurerm" {
  features {

  }
}

# Create a resource group

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create a virtual network

resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  address_space       = [var.network_vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet for the application

resource "azurerm_subnet" "public_subnet" {
  name                 = var.public_subnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.public_subnet_cidr]
}

# Create a subnet for the DB

resource "azurerm_subnet" "private_subnet" {
  name                 = var.private_subnet
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.private_subnet_cidr]
}


# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  name                = var.public_ip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create public IPs
resource "azurerm_public_ip" "lb_ip" {
  name                = var.lb_ip
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a NSG for the application

resource "azurerm_network_security_group" "app-nsg" {
  name                = "app_nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "182.72.58.210/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "port8080"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 8080
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# Create a NSG for the application

resource "azurerm_network_security_group" "db-nsg" {
  name                = "db_nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "postgres"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 5432
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

}


# Generate random password
resource "random_password" "linux-vm-password" {
  length           = 7
  min_upper        = 2
  min_lower        = 2
  min_special      = 2
  numeric          = true
  special          = true
  override_special = "!@#$%&"
}

resource "azurerm_availability_set" "as" {
  name                = "webapp"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create app virtual machine
resource "azurerm_linux_virtual_machine" "app_vm" {
  name                  = "app_vm${count.index}"
  count                 = 3
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.app-nic.*.id, count.index)]
  size                  = var.azurerm_linux_virtual_machine_size
  availability_set_id   = azurerm_availability_set.as.id

  os_disk {
    name                 = "appdisk${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  computer_name  = "ubuntu"
  admin_username = var.linux_admin_username
  admin_password = random_password.linux-vm-password.result
  disable_password_authentication = false
}


# Create DB virtual machine
resource "azurerm_linux_virtual_machine" "db_vm" {
  name                  = "db_vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.db-nic.id]
  size                  = var.azurerm_linux_virtual_machine_size

  os_disk {
    name                 = "dbdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  computer_name  = "ubuntu"
  admin_username = var.linux_admin_username
  admin_password = random_password.linux-vm-password.result
  disable_password_authentication = false
}


#Create a load balancer for the VM's that running the application

resource "azurerm_lb" "lb" {
  name                = "app_lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}

# Create a health probe for load balancer

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "app-health-probe"
  port            = 8080
}

# Create a load balancer rule

resource "azurerm_lb_rule" "tcp" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "app-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  probe_id                       = azurerm_lb_probe.lb_probe.id
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  disable_outbound_snat          = true
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.bp.id]
}

resource "azurerm_lb_nat_rule" "ssh-nat-rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  count                          = 3
  name                           = "ssh-nat-rule${count.index}"
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  protocol                       = "Tcp"
  frontend_port                  = "500${count.index}"
  backend_port                   = 22
}

resource "azurerm_lb_outbound_rule" "test" {
  loadbalancer_id = azurerm_lb.lb.id
  name = "outboundRule"
  protocol = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bp.id

  frontend_ip_configuration {
    name = "LoadBalancerFrontEnd"
  }
}


#NAT rule asssociation:

resource "azurerm_network_interface_nat_rule_association" "nat-association" {
  count  =  3
  network_interface_id  = azurerm_network_interface.app-nic[count.index].id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.ssh-nat-rule[count.index].id
}

# Create a backend pool for load balancer

resource "azurerm_lb_backend_address_pool" "bp" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "app-pool"
}

resource "azurerm_lb_backend_address_pool_address" "bp-address" {
  count                   = 3
  name                    = "lb-bepool-address-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bp.id
  virtual_network_id      = azurerm_virtual_network.vnet.id
  ip_address              = azurerm_network_interface.app-nic[count.index].private_ip_address
}



# Create a network interface for app vm

resource "azurerm_network_interface" "app-nic" {
  name                = "app-nic${count.index}"
  count               = 3
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


# Create a network interface for db vm

resource "azurerm_network_interface" "db-nic" {
  name                = "db-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "app" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.app-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.app-nsg.id
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "db" {
  network_interface_id      = azurerm_network_interface.db-nic.id
  network_security_group_id = azurerm_network_security_group.db-nsg.id
}



# Creating backend storage :

terraform {
  backend "azurerm" {
    resource_group_name  = "tfstorage"
    storage_account_name = "tfstatestoragebootcamp"
    container_name       = "tfcontainernew"
    key                  = "terraform.tfstate"
  }
}
