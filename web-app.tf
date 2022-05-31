terraform{
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "=3.0.0"
        }
    }
}

provider "azurerm" {
    features {}
    subscription_id = "f9bf6f1c-3e96-4c71-870b-74211270087e"
}

resource "azurerm_resource_group" "nuwm-cloud" {
    name     = "nuwm-cloud"
    location = "Australia Central"
}

resource "azurerm_virtual_network" "nuwm-cloud" {
    name                = "nuwm-network"
    location            = azurerm_resource_group.nuwm-cloud.location
    resource_group_name = azurerm_resource_group.nuwm-cloud.name
    address_space       = [ "10.0.0.0/16" ]
}

resource "azurerm_subnet" "vm-subnet" {
    name                 = "vm-subnet"
    address_prefixes     = [ "10.0.1.0/24" ]
    virtual_network_name = azurerm_virtual_network.nuwm-cloud.name
    resource_group_name  = azurerm_resource_group.nuwm-cloud.name
}

resource "azurerm_public_ip" "vm-public" {
    name                = "vm-public"
    resource_group_name = azurerm_resource_group.nuwm-cloud.name
    location            = azurerm_resource_group.nuwm-cloud.location
    allocation_method   = "Static"
    sku                 = "Standard"
}

resource "azurerm_public_ip" "lb-public" {
    name                = "lb-public"
    resource_group_name = azurerm_resource_group.nuwm-cloud.name
    location            = azurerm_resource_group.nuwm-cloud.location
    allocation_method   = "Static"
    sku                 = "Standard"
}

resource "azurerm_network_security_group" "nuwm-cloud-security-public" {
    name                = "nuwm-security-group-public"
    location            = azurerm_resource_group.nuwm-cloud.location
    resource_group_name = azurerm_resource_group.nuwm-cloud.name
}

resource "azurerm_network_security_rule" "allow-ping" {
    name                        = "allow-ping"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Icmp"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name         = azurerm_resource_group.nuwm-cloud.name
    network_security_group_name = azurerm_network_security_group.nuwm-cloud-security-public.name
}

resource "azurerm_network_security_rule" "allow-ssh" {
    name                        = "allow-ssh"
    priority                    = 110
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name         = azurerm_resource_group.nuwm-cloud.name
    network_security_group_name = azurerm_network_security_group.nuwm-cloud-security-public.name
}

resource "azurerm_network_interface" "vm-net-interface-pub" {
    name                = "vm-net-interface-pub"
    location            = azurerm_resource_group.nuwm-cloud.location
    resource_group_name = azurerm_resource_group.nuwm-cloud.name

    ip_configuration {
        name                          = "public"
        private_ip_address_allocation = "Dynamic"
        subnet_id                     = azurerm_subnet.vm-subnet.id
        public_ip_address_id          = azurerm_public_ip.vm-public.id
    }
}

resource "azurerm_network_interface_security_group_association" "security-pub" {
    network_interface_id      = azurerm_network_interface.vm-net-interface-pub.id
    network_security_group_id = azurerm_network_security_group.nuwm-cloud-security-public.id
}

resource "azurerm_linux_virtual_machine" "management" {
    name                            = "management"
    resource_group_name             = azurerm_resource_group.nuwm-cloud.name
    location                        = azurerm_resource_group.nuwm-cloud.location
    size                            = "Standard_B1ls"
    admin_username                  = "mitsugi"
    admin_password                  = "s1c2v3l4t5SS7"
    disable_password_authentication = false
    network_interface_ids = [
        azurerm_network_interface.vm-net-interface-pub.id,
    ]
    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
}

resource "azurerm_network_interface" "vm-net-interface-private" {
    count               = 2
    name                = "vm-net-interface-private-${count.index}"
    location            = azurerm_resource_group.nuwm-cloud.location
    resource_group_name = azurerm_resource_group.nuwm-cloud.name

    ip_configuration {
        name                          = "internal"
        subnet_id                     = azurerm_subnet.vm-subnet.id
        private_ip_address_allocation = "Dynamic"
    }
    enable_ip_forwarding = false
}

resource "azurerm_network_security_group" "nuwm-cloud-security-http" {
    name                = "nuwm-cloud-security-http"
    location            = azurerm_resource_group.nuwm-cloud.location
    resource_group_name = azurerm_resource_group.nuwm-cloud.name
}

resource "azurerm_network_security_rule" "allow-http" {
    name                        = "allow-http"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "80"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
    resource_group_name         = azurerm_resource_group.nuwm-cloud.name
    network_security_group_name = azurerm_network_security_group.nuwm-cloud-security-http.name
}

resource "azurerm_network_interface_security_group_association" "security-private" {
    count                     = 2
    network_interface_id      = element( azurerm_network_interface.vm-net-interface-private.*.id, count.index)
    network_security_group_id = azurerm_network_security_group.nuwm-cloud-security-http.id
}

resource "azurerm_linux_virtual_machine" "web" {
    count                           = 2
    name                            = "web-${count.index}"
    resource_group_name             = azurerm_resource_group.nuwm-cloud.name
    location                        = azurerm_resource_group.nuwm-cloud.location
    size                            = "Standard_B1ls"
    admin_username                  = "miriam"
    admin_password                  = "s1c2v3l4t5SS7"
    disable_password_authentication = false
    network_interface_ids = [
        element( azurerm_network_interface.vm-net-interface-private.*.id, count.index)
    ]
    
    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
}

resource "azurerm_lb" "web-app-lb" {
    name                = "Web-app-LB"
    location            = azurerm_resource_group.nuwm-cloud.location
    resource_group_name = azurerm_resource_group.nuwm-cloud.name
    sku                 = "Standard"

    frontend_ip_configuration {
        name                          = "primary"
        public_ip_address_id          = azurerm_public_ip.lb-public.id
        private_ip_address_allocation = "Dynamic"
    }

    depends_on          = [azurerm_linux_virtual_machine.web]
}

resource "azurerm_lb_probe" "http-probe" {
    //resource_group_name = azurerm_resource_group.nuwm-cloud.name
    loadbalancer_id     = azurerm_lb.web-app-lb.id
    name                = "http-running-probe"
    port                = 80

    depends_on = [azurerm_linux_virtual_machine.web, azurerm_lb.web-app-lb]
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
    name            = "LB-backend_address_pool"
    loadbalancer_id = azurerm_lb.web-app-lb.id
    
    depends_on = [azurerm_linux_virtual_machine.web, azurerm_lb.web-app-lb]
}

resource "azurerm_lb_rule" "http-rule" {
    //resource_group_name            = azurerm_resource_group.nuwm-cloud.name
    loadbalancer_id                = azurerm_lb.web-app-lb.id
    name                           = "HTTP"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = azurerm_lb.web-app-lb.frontend_ip_configuration.0.name
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
    probe_id                       = azurerm_lb_probe.http-probe.id

    depends_on = [
        azurerm_linux_virtual_machine.web,
        azurerm_lb.web-app-lb,
        azurerm_lb_backend_address_pool.backend_pool,
        azurerm_network_interface_backend_address_pool_association.web,
        azurerm_lb_probe.http-probe
    ]
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
    count = 2
    backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
    ip_configuration_name = element(azurerm_network_interface.vm-net-interface-private.*.ip_configuration.0.name, count.index)
    network_interface_id =  element(azurerm_network_interface.vm-net-interface-private.*.id, count.index)

    depends_on = [
      azurerm_lb.web-app-lb,
      azurerm_lb_backend_address_pool.backend_pool
    ]
}