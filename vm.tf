# Metadata value fields in Openstack provider can be only 255 byte long.
# So we split WinRM public certificate in 4 pieces so Cloubase-Init will stitch them together.
locals {
    winrm_cert = {
        cert_splitted = var.winrm_cert_path != "" ? {
            admin_cert0 = substr (filebase64(pathexpand("${var.winrm_cert_path}")),0,255)
            admin_cert1 = substr (filebase64(pathexpand("${var.winrm_cert_path}")),255,255)
            admin_cert2 = substr (filebase64(pathexpand("${var.winrm_cert_path}")),510,255)
            admin_cert3 = substr (filebase64(pathexpand("${var.winrm_cert_path}")),765,255)
        } : null
    }
    # Merge other Metadata with WinRM splitted certificate
    metadata = merge(local.winrm_cert.cert_splitted,var.metadata)
}

# Create computing instance with root volume and first port inside otherwise instance will not boot correctly
resource "openstack_compute_instance_v2" "vm" {
    name                = var.name
    availability_zone   = var.az
    region              = var.region
    flavor_name         = var.flavor
    key_pair            = var.ssh_key_name
    metadata            = local.metadata
    user_data           = var.user_data == "" ? null : var.user_data
    config_drive        = var.config_drive == false ? null : var.config_drive
    # If 'pinned_root_drive' flag is set, create root volume instead of using volume created in 'volumes.tf'
    block_device {
        boot_index          = 0
        uuid                = var.pinned_root_drive ? data.openstack_images_image_v2.image.id : openstack_blockstorage_volume_v2.volumes["root"].id
        source_type         = var.pinned_root_drive ? "image" : "volume"
        destination_type    = "volume"
        volume_size         = var.pinned_root_drive ? var.volumes["root"].size : null
    }
    network {
        port            = openstack_networking_port_v2.ports[0].id
    }
}
