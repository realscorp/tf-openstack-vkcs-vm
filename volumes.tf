# Get image id by name
data "openstack_images_image_v2" "image" {
    name                = var.image
}

# Create all Volumes except of 'root' volume if 'pinned_root_drive' flag is set
resource "openstack_blockstorage_volume_v2" "volumes" {
    for_each            = var.pinned_root_drive ? { 
        for k,v in var.volumes : k => v
        if k != "root" 
        } : var.volumes
    region              = var.region
    availability_zone   = var.az
    name                = "${var.name}-${each.key}"
    # If Volume is root then create it from Image
    image_id            = each.key == "root" ? data.openstack_images_image_v2.image.id : ""
    volume_type         = each.value.type
    size                = each.value.size

    # !!! VKCS-specific workarounds
    lifecycle {
        ignore_changes = [
            availability_zone, # cause NVME volumes will change their az to 'nova' after creation
            snapshot_id, # ignore it in case we did manual volume restoring from VKCS snapshot or backup
            metadata # ignore it cause VKCS can change metadata
        ]
    }
}

# Using 'volume_attach' instead of attaching Volumes in 'computing_instance' resource because
# this way we can modify, add or delete Volumes without Instance being recreated.
# Only root Volume should be attached in 'computing_instance' or Instance will not boot correctly
resource "openstack_compute_volume_attach_v2" "volume_attach" {
    for_each            = {
        for k,v in var.volumes : k => v
        if k != "root"
    }
    instance_id         = openstack_compute_instance_v2.vm.id
    volume_id           = openstack_blockstorage_volume_v2.volumes[each.key].id
}
