variable "name" {
  type = string
  description = "Computing instance name"
}
variable "flavor" {
  type = string
  description = "Computing instance flavor name"
}
variable "user_data" {
  type = string
  default = ""
  description = "Content of 'user_data' for Cloud-Init"
}
variable "config_drive" {
  type = bool
  default = false
  description = "config_drive option usage flag"
}
variable "winrm_cert_path" {
  type = string
  default = ""
  description = "Path to WinRM public certificate file in DER format"
}
variable "ssh_key_name" {
  type = string
  default = null
  description = "SSH keypair in Openstack platform public key name"
}
variable "metadata" {
  type = map
  description = "Metadata in key=value format. Can be used for Ansible dynamic inventory"
}
variable "az" {
  type = string
  default = "MS1"
  description = "Computing instance avaliability zone"
}
variable "region" {
  type = string
  default = "RegionOne"
  description = "Openstack project Region"
}
variable "image" {
  type = string
  description = "Image name"
}
variable "dns_ttl" {
  type = number
  default = 300
  description = "TTL for created DNS records"
}
variable "pinned_root_drive" {
  type = bool
  default = false
  description = "Create root drive inside of openstack_computing_instance resource. Could be useful for VKCS instances with NVME volumes"
}
variable "ports"{
  description = "List of Ports"
  type = list (object({
    network = string
    subnet = string
    ip_address = string
    dns_record = bool
    dns_zone = string
    security_groups = list(string)
    security_groups_ids = list(string)
  }))
}
variable "volumes"{
  description = "List of Volumes to attach to Instance. Boot drive should always have 'root' name"
  type = map (object({
    type = string
    size = number
  }))
}