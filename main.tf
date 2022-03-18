# Using recommended by VKCS version of Openstack
terraform {
    required_providers {
        openstack = {
        source = "terraform-provider-openstack/openstack"
        version = "1.33.0"
        }
    }
}
