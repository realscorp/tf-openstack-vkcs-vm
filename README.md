# Openstack instance module (VKCS)
Terraform module designed to simplify and standardize day-by-day Openstack computing instance creation and operations.  
Some workarounds, defaults and constrains are specific for **VKCS** ([mcs.mail.ru](https://mcs.mail.ru/)) cloud platform, but feel free to use it as a starting point to create your own module for your Openstack hostring provider.
## Features
- Use names for Flavor and Image instead of ids
- Simple to use Volume list. Just name a volume and set it's size and type. Name it 'root' for boot Volume.
- Powerful yet simple Port list.
- Automatic DNS A-records creation
- Easy to use Windows-instance configuration for WinRM certificate-based access
- Standardized names for objects created with Instance
- Few times lesser amount of code for same Instance using this module
- Easy to use with 'count' and 'for_each'
### Without module
<details>
  <summary>71 lines of code and it become much more messy when you need more instances</summary>

    data "openstack_compute_flavor_v2" "standard-2-4-50" {
        name = "Standard-2-4-50"
    }
    data "openstack_images_image_v2" "win2019en" {
        name = "Windows-Server-2019Std-en.202105"
    }
    locals {
        winrm_cert = {
            winrm-sf-prod-main = {
                admin_cert0 = substr (filebase64("~/.winrm/winrm.der"),0,255)
                admin_cert1 = substr (filebase64("~/.winrm/winrm.der"),255,255)
                admin_cert2 = substr (filebase64("~/.winrm/winrm.der"),510,255)
                admin_cert3 = substr (filebase64("~/.winrm/winrm.der"),765,255)
            }
        }
    }
    resource "openstack_compute_keypair_v2" "ansible-key" {
        name       = "ansible-key"
        public_key = file("~/.ssh/id_rsa.pub")
    }
    resource "openstack_blockstorage_volume_v2" "win-example-c" {
    name     = "win-example-c"
    size     = 60
    volume_type  = "ceph-ssd"
    availability_zone = "MS1"
    image_id = data.openstack_images_image_v2.win2019en.id
    }
    resource "openstack_blockstorage_volume_v2" "win-example-bases" {
    name     = "win-example-bases"
    size     = 120
    volume_type  = "ceph-ssd"
    availability_zone = "MS1"
    }
    resource "openstack_compute_instance_v2" "win-example" {
        availability_zone = "MS1"
        name            = "win-example"
        flavor_id       = data.openstack_compute_flavor_v2.standard-2-4-50.id
        security_groups = ["i_default", "o_default"]
        key_pair = "ansible-key"
        network {
            name = "network-1"
            fixed_ip_v4 = "10.0.0.10"
        }
        block_device {
            uuid                  = "${openstack_blockstorage_volume_v2.win-example-c.id}"
            source_type           = "volume"
            boot_index            = 0
            destination_type      = "volume"
            delete_on_termination = false
        }
        metadata = merge(
            local.winrm_cert.winrm-sf-prod-main,
                {
                    os = "windows"
                    os_ver = "2019"
                    app = "example"
                }
            )
    }
    resource "openstack_compute_volume_attach_v2" "bases" {
        instance_id = "${openstack_compute_instance_v2.win-example.id}"
        volume_id   = "${openstack_blockstorage_volume_v2.win-example-bases.id}"
    }
    resource "dns_a_record_set" "dns" {
        zone = "example.com."
        name = openstack_compute_instance_v2.win-example.name
        addresses = [
            openstack_compute_instance_v2.win-example.network[0].fixed_ip_v4
        ]
        ttl = 300
    }

</details>

### With module
<details>
  <summary>34 lines of easy-to-read code</summary>

    module "win-example" {
        source          = "git::https://github.com/realscorp/tf-openstack-vkcs-vm.git?ref=v1.0.0"
        name            = "win-example"
        flavor          = "standard-2-4-50"
        image           = "Windows-Server-2019Std-en.202105"
        ssh_key_name    = "ansible-key"
        winrm_cert_path = "~/.winrm/winrm.der"
        metadata        = {
                os              = "windows"
                os_ver          = "2019"
                app             = "EXAMPLE"
            }
        ports = [
            {
                network         = "network-1"
                subnet          = "subnet-1"
                ip_address      = ""
                dns_record      = true
                dns_zone        = "example.com."
                security_groups = ["i_default", "o_default"]
                security_groups_ids = []
            }
        ]
        volumes = {
            root = {
                type            = "ceph-ssd"
                size            = 60
            }
            bases = {
                type            = "ceph-ssd"
                size            = 120
            }
        }
    }

</details>

## Variables
- **name** *(string; **required**)* - Instance name
- **flavor** *(string; **required**)* - Instance flavor
- **image** *(string; **required**)* - Instance image
- **image** *(map; **required**)* - Key-value list of Metadata tags, you can use with Ansible dynamic inventory plugin to dynamicaly create inventory groups
- **pinned_root_drive** *(boolean; default: false)* - Create root-volume inside of Instance resource. Should be used for NVME instance type.
- **user_data** *(string)* - Additional configuration to apply via Cloud-Init
- **config_drive** *(boolean)* - Create instance with configuration store drive attached. This drive used to pass platform metadata to Instance in case of default mechanism cannot be used (e.g. only External network interface is present)
- **winrm_cert_path** *(string)* - filepath to public WinRM certificate in DER format. It can be used to setup Windows Instance for WinRM connections with certificate authentication.
- **ssh_key_name** *(string)* - SSH keypair name
- **az** *(string; default: MS1)* - avaliability zone to create Instance
- **region** *(string; default: RegionOne)* - cloud project region
- **dns_ttl** *(number; default: 300)* - TTL for automatic DNS A-records
- **ports** *(list(object))* - list of network Ports
  - **network** *(string; **required, cannot be empty**)* - network name to create port into (in case of external ip is needed, use "ext-net" name)
  - **subnet** *(string; **required**, can be "")* - subnet name in case of fixed IP address is set (cannot be set if network name is "ext-name")
  - **ip_address** *(string; **required**, can be "")* - fixed IP address. If empty, IP address will be assigned automatically via DHCP
  - **dns_record** *(boolean; **required**)* - create A-record for created port' IP address
  - **dns_zone** *(string; **required**, can be "")* - FQDN-name of DNS zone to create record in (should end with dot)
  - **security_groups** *(list(string); **required**, can be "")* - firewall Security Group names list
  - **security_groups_ids** *(list(string); **required**, can be "")* - firewall Security Group ID list. Can be used to create Security Group at the same time as instance otherwise Terraform won't be able to create recource graph
- **volumes** *(map(object); **required**)* - list of Volumes to attach to Instance
  - **type** *(string; **required**)* - Volume type (ceph-hdd/ceph-ssd/high-iops etc)
  - **size** *(number; **required**)* - Volume size in GB
## Output
- **vm** - export all Opentack Computing Instance arguments
- **ports** - export all Opentack Networking Port arguments in form of list
- **volumes** - export all Opentack Volumes arguments in form of map
- **dns** - export all Opentack Volumes arguments in form of list

# Requirements
You should have [Openstack provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs) declared and set up in your root module. If you are to use DNS record creation, you should also have [Hashicorp DNS provider](https://registry.terraform.io/providers/hashicorp/dns/latest/docs) set-up.
<details>
  <summary>Example of <b>main.tf</b> in your root module</summary>

    terraform {
        required_providers {
            openstack = {
            source = "terraform-provider-openstack/openstack"
            version = "1.33.0"
            }
        }
    }
    # Setting for Microsoft DNS to authenticate via GSS-TSIG against Microsoft AD
    provider "dns" {
        update {
            server = "dc1.your.domain.com"
            gssapi {
                realm    = "YOUR.DOMAIN.COM"
                username = "service-account"
                password   = "service-password"
            }
        }
    }

</details>
<details>
  <summary>Example of <b>init.sh</b> to set-up providers via enviromental variables</summary>

    #!/usr/bin/env bash
    # Openstack (VKCS)
    export OS_AUTH_URL="https://infra.mail.ru:35357/v3/"
    export OS_PROJECT_ID="xxxxxxxxxxxxxxxxxxxxxxx"
    export OS_REGION_NAME="RegionOne"
    export OS_USER_DOMAIN_NAME="users"
    # Remove legacy vars
    unset OS_TENANT_ID
    unset OS_TENANT_NAME
    unset OS_PROJECT_NAME
    unset OS_PROJECT_DOMAIN_ID
    # Ask for credentials if it is not set already
    if [[ -z $OS_USERNAME ]] || [[ -z $OS_PASSWORD ]]; then
        echo "Please enter your OpenStack Username for project $OS_PROJECT_ID: "
        read -sr OS_USERNAME_INPUT
        export OS_USERNAME=$OS_USERNAME_INPUT

        echo "Please enter your OpenStack Password for project $OS_PROJECT_ID as user $OS_USERNAME: "
        read -sr OS_PASSWORD_INPUT
        export OS_PASSWORD=$OS_PASSWORD_INPUT
    fi  
    # Set krb5_config file location so GSS-TSIG by Kerberos can be used for authentication
    export KRB5_CONFIG=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )/krb5_config

</details>
<details>
  <summary>Example of <b>krb5_config</b> to set-up Kerberos auth for Microsoft DNS server</summary>

    [libdefaults]
    default_realm = YOUR.DOMAIN.COM
    [realms]
    YOUR.DOMAIN.COM = {
    kdc = dc1.your.domain.com
    kdc = dc2.your.domain.com
    }

</details>

# Examples
<details>
  <summary><b>Simple Ubuntu instance</b></summary>

    module "ubuntu-vm" {
        source          = "git::https://github.com/realscorp/tf-openstack-vkcs-vm.git?ref=v1.0.0"
        name            = "ubuntu-vm"
        flavor          = "Standard-4-8-80"
        image           = "Ubuntu-20.04.1-202008"
        ssh_key_name    = "ansible-key"
        metadata        = {
                os_ver  = "ubuntu20"
            }
        ports = [
            {
                network         = "network-1"
                subnet          = ""
                ip_address      = ""
                dns_record      = true
                dns_zone        = "example.com."
                security_groups = ["i_default","o_default"]
                security_groups_ids = []
            }
        ]
        volumes = {
            root = {
                type            = "ceph-ssd"
                size            = 10
            }
        }
    }

</details>
<details>
  <summary><b>Complex Windows instance</b></summary>

    # Create Security Group alongside with Instance
    module "i_int_test" {
        source  = "git::https://github.com/realscorp/tf-openstack-vkcs-secgroup.git?ref=v1.0.0"
        name    = "i_int_test"
        rules   = [{
                    direction   = "ingress"
                    protocol    = "tcp"
                    ports       = ["80","443"]
                    remote_ips = {
                        "Office IT subnet" = "10.10.0.0/24"
                        "Office Sales subnet" = "10.11.0.0/24"
                        "Office PM subnet" = "10.12.0.0/24"
                        "Server 1" = "10.0.0.11"
                        "Server 2" = "10.0.0.12"
                        }
                }]
    }
    
    # We'll set even optional variables
    module "windows-vm" {
        source          = "git::https://github.com/realscorp/tf-openstack-vkcs-vm.git?ref=v1.0.0"
        name            = "windows-vm"
        flavor          = "Standard-4-8-80"
        az              = "DP1"
        dns_ttl         = 600
        region          = "RegionOne"
        image           = "Windows-Server-2019Std-en.202105"
        winrm_cert_path = "~/.winrm/winrm.der"
        ssh_key_name    = "ansible-key"
        user_data       = file(pathexpand("${path.module}/some.userdata"))
        metadata        = {
                os                  = "windows"
                os_ver              = "2019"
                app                 = "test"
            }
        ports = [
            {
                network             = "network-1"
                subnet              = "subnet-1"
                ip_address          = "10.0.0.10"
                dns_record          = true
                dns_zone            = "example.com."
                security_groups     = ["i_default","o_default"]
                security_groups_ids = [module.i_int_test.sg.id]
            },
            {
                network             = "ext-net"
                subnet              = ""
                ip_address          = ""
                dns_record          = false
                dns_zone            = ""
                security_groups     = ["o_default"]
                security_groups_ids = []
            }
        ]
        volumes = {
            root = {
                type                = "ceph-ssd"
                size                = 50
            }
            bases = {
                type                = "high-iops"
                size                = 100
            }
            logs = {
                type                = "ceph-ssd"
                size                = 20
            }
        }
    }

</details>
<details>
  <summary><b>Instance with local NVME-drives</b></summary>

    module "nvme-vm" {
        source              = "git::https://github.com/realscorp/tf-openstack-vkcs-vm.git?ref=v1.0.0"
        name                = "nvme-vm"
        flavor              = "NVME-Freq-16-64"
        image               = "Ubuntu-20.04.1-202008-NVME"
        ssh_key_name        = "ansible-key"
        winrm_cert_path     = "~/.winrm/winrm.der"
        pinned_root_drive   = true
        metadata        = {
                os_ver          = "ubuntu20"
                os              = "linux"
            }
        ports = [
            {
                network         = "network-1"
                subnet          = ""
                ip_address      = ""
                dns_record      = false
                dns_zone        = "test.com."
                security_groups = ["i_default","o_default"]
                security_groups_ids = []
            }
        ]
        volumes = {
            root = {
                type            = "ef-nvme"
                size            = 20
            }
            bases = {
                type            = "ef-nvme"
                size            = 30
            }
        }
    }

</details>
<details>
  <summary><b>Output usage examples</b></summary>

    # Get all Computing Instance properties
    output "vm" {
        value = module.windows-vm.vm
    }

    # Get all Volume properties
    output "volumes" {
        value = module.windows-vm.volumes
    }

    # Get ip-address obtained by port via DHCP
    output "port_ip" {
        value = module.windows-vm.ports[0].all_fixed_ips[0]
    }

    # Get DNS properties
    output "dns" {
        value = module.windows-vm.dns
    }

</details>

# Author
[Sergey Krasnov](https://github.com/realscorp)