# Выхлоп с данными об инстансе
output "vm" {
    value = openstack_compute_instance_v2.vm
}
# Выхлоп с данными о дисках
output "volumes" {
    value               = openstack_blockstorage_volume_v2.volumes
}
# Выхлоп в виде созданных портов
output "ports" {
    value               = openstack_networking_port_v2.ports
}
# Выхлоп о записи dns
output "dns" {
    value = dns_a_record_set.dns
}