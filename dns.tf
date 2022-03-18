# Create DNS records for every port that has 'dns_record' flag set to 'true'
resource "dns_a_record_set" "dns" {
    for_each = {
        for idx, port in var.ports : idx => port
        if port.dns_record
    }
    zone = each.value.dns_zone
    name = var.name
    addresses = [
        openstack_networking_port_v2.ports[each.key].all_fixed_ips[0]
    ]
    ttl = var.dns_ttl
}
