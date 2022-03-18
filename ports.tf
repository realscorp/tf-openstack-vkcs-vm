# Create flat list of all Security Groups and remove empty lines and duplicates
locals {
    all_sec_groups      = distinct(flatten([for sg in var.ports : sg.security_groups]))
}
# Get IDs of all used Security Groups so we can ref them by name
data "openstack_networking_secgroup_v2" "secgroup" {
    for_each            = toset(local.all_sec_groups)
    name                = each.key
}

# Convert 'ports' list to a map so we can use 'for_each'
locals {
    ports_map           = {for idx, port in var.ports : idx => port}
}
# Get all Network object IDs
data "openstack_networking_network_v2" "network" {
    for_each            = local.ports_map
    name                = each.value.network
}
# All ports with fixed ip-address set should have 'subnet' set
data "openstack_networking_subnet_v2" "subnet_fixed" {
    for_each            = {
        for idx, port in var.ports : idx => port
        if port.subnet != ""
    }
    network_id          = data.openstack_networking_network_v2.network[each.key].id
    name                = each.value.subnet
}

# Create ports
resource "openstack_networking_port_v2" "ports" {
    for_each = local.ports_map
    name                = "port-${var.name}-${each.value.network}-${each.key}"
    network_id          = data.openstack_networking_network_v2.network[each.key].id
    # Dynamic block for ports with 'fixed_ip' set
    dynamic "fixed_ip" {
        for_each = each.value.ip_address != "" ? toset([1]) : toset([])
        content {
            subnet_id   = data.openstack_networking_subnet_v2.subnet_fixed[each.key].id
            ip_address  = each.value.ip_address
        }
    }
    # Add Security groups by concatenated list
    security_group_ids  = concat(
        # Add Security groups by name list
        tolist([for sg in each.value.security_groups : data.openstack_networking_secgroup_v2.secgroup[sg].id]),
        # Add Security groups by ID list
        each.value.security_groups_ids
    )
    
}

# Attach all Ports except of first one because it will be used inside of computing_instance resource
# If we'll attach first Port here the instance will not boot correctly
resource "openstack_compute_interface_attach_v2" "port_attachments" {
    count               = length(var.ports) - 1 
    instance_id         = "${openstack_compute_instance_v2.vm.id}"
    port_id             = "${openstack_networking_port_v2.ports[(count.index + 1)].id}"
}
