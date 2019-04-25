# Configure the Oracle Cloud Infrastructure Classic provider
provider "opc" {
  user            = "some.user@email.com"
  password        = "passwordhere"
  identity_domain = "idd_here"
  endpoint        = "https://compute.uscom-east-1.oraclecloud.com"
}


# create security list (shared network)
# A security list is a group of Oracle Compute Cloud Service instances that you can specify as the source or destination in one or more security rules.
# The instances in a  security list can communicate fully, on all ports, with other instances in the same security list using their private IP addresses.
#
#If the outbound_cidr_policy for a security list (seclist) is set to DENY, you can create security rules (secrules) to #enable outbound communication from the instances #within that security list to public IP addresses (seciplists). This #way, you can create holes in the outbound firewall. You cannot create security rules to enable #outbound communication #from a security list to public IP addresses if the outbound_cidr_policy for the security list is set to PERMIT.



resource "opc_compute_security_list" "testbox1_sec_list1" {
  name                 = "testbox1_sec_list1"
  policy               = "PERMIT"
  outbound_cidr_policy = "PERMIT"
}

# A security IP list is a list of IP subnets (in the CIDR format) or IP addresses that are external to instances in OCI Classic.
# You can use a security IP list as the source or the destination in security rules to control network access to or from Classic instances.
# create security iplist
resource "opc_compute_security_ip_list" "testbox1_sec_ip_list1" {
  name       = "testbox1_sec_ip_list1"
  ip_entries = ["0.0.0.0/0"]
}

# create security application
resource "opc_compute_security_application" "testbox1_security_application_sftp" {
  name     = "testbox1_security_application_sftp"
  protocol = "tcp"
  dport    = "2222"
}

# Security rules are essentially firewall rules, which you can use to permit traffic
# between Oracle Compute Cloud Service instances in different security lists, as well as between instances and external hosts.
## create security rule  (shared network)
resource "opc_compute_sec_rule" "testbox1_secrule" {
  name             = "testbox1_secrule"
  source_list      = "seclist:${opc_compute_security_list.testbox1_sec_list1.name}"
  destination_list = "seciplist:${opc_compute_security_ip_list.testbox1_sec_ip_list1.name}"
  action           = "permit"
  application      = "${opc_compute_security_application.testbox1_security_application_sftp.name}"
}

# Create an IP Reservation
resource "opc_compute_ip_reservation" "testbox1_ipreservation" {
  name = "testbox1_ipreservation"
  parent_pool = "/oracle/public/ippool"
  permanent = true
}


resource "opc_compute_storage_volume" "testbox1_disk_boot" {
  name             = "testbox1_disk_boot"
  description      = "testbox1_disk_boot boot disk"
  size             = 30
  bootable         = true
  image_list       = "/oracle/public/OL_7.2_UEKR4_x86_64"
  image_list_entry = 1
  lifecycle {
    prevent_destroy = true
}

}



## create storage volumes
resource "opc_compute_storage_volume" "testbox1_disk_1" {
  name = "testbox1_disk_1"
  size = 20
}

resource "opc_compute_storage_volume" "testbox1_disk_2" {
  name = "testbox1_disk_2"
  size = 20
}

resource "opc_compute_ssh_key" "testbox1_ssh_pubkey" {
  name    = "testbox1_ssh_pubkey"
  key     = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAhPiXArgPV8Y1UW6IPSIGNPZUbMrlbgneNw2RmPuhOISFBz7h6A6BlUXNsQgnp5VwoXGvQ3fGpAx0FkB4vrkJ6BgkS3fNEzoTcGy2swMteghvT3o9nsX5WlHx0aBifwuDIbmFfhYggjoN5lUvPrmk+wsa/18swXw8gmbPWtn8uX1m6Ms8IeEOtOHSabNnyTGpwX0LbYIZp8OQbT++x0Epf5YIehXmc7/GT40G0ZWbJmmAXjaWzSHHuceyxVndvVupJpJJVOhimxaaYk2dhKhc4DvEW5mcalSaNSd5GZ7gG4JTIzlQojwGDz6mt8X+gjvnxL/QOoiBkxqAtokz4BUlJw== gen_purpose_key"
  enabled = true
}

## pointers. 
## security-list will be listed in the instance json, 
## to find secrule , list all secrules and find the seclist in the secrule.
## in the cloud-UI , it takes a long time for the security list to show under instance.





##             Now create the instance                     ##
##---------------------------------------------------------##


resource "opc_compute_orchestrated_instance" "testbox1_orch" {
  name          = "testbox1_orch"
  desired_state = "active"


  instance {
    name       = "testbox1_instance"
    label      = "testbox1_instance"
    shape       = "oc3"
    #image_list = "/oracle/public/OL_7.2_UEKR4_x86_64"



    storage {
     volume = "${opc_compute_storage_volume.testbox1_disk_boot.name}"
     index = 1
    }

    storage {
      volume = "${opc_compute_storage_volume.testbox1_disk_1.name}"
      index  = 2
    }


    storage {
      volume = "${opc_compute_storage_volume.testbox1_disk_2.name}"
      index  = 3
    }

    boot_order = [ 1 ]

    networking_info {
      index          = 0
      nat            = ["${opc_compute_ip_reservation.testbox1_ipreservation.name}"]
      sec_lists      = ["${opc_compute_security_list.testbox1_sec_list1.name}"]
      shared_network = true
    }

    ssh_keys = ["${opc_compute_ssh_key.testbox1_ssh_pubkey.name}"]
  }
}


output "public_ip_reservation" {
  value ="${opc_compute_ip_reservation.testbox1_ipreservation.ip}"
}