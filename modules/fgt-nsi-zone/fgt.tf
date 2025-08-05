#
# Create FortiGate instances with secondary logdisks and configuration.
#
resource "google_compute_disk" "logdisk" {
  count = var.logdisk_size > 0 ? var.cluster_size : 0

  name = "${local.prefix}disk-logdisk${count.index + 1}-${local.zone_short}"
  size = var.logdisk_size
  type = "pd-ssd"
  zone = var.zone
}

#
# Prepare bootstrap data
# - part 1 is optional FortiFlex license token
# - part 2 is bootstrap configuration script built from fgt_config.tftpl template
#
data "cloudinit_config" "fgt" {
  count = var.cluster_size

  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = try(var.flex_tokens[count.index], "") == "" ? [] : [1]
    content {
      filename     = "license"
      content_type = "text/plain; charset=\"us-ascii\""
      content      = <<-EOF
        LICENSE-TOKEN: ${var.flex_tokens[count.index]}
        EOF
    }
  }

  part {
    filename     = "config"
    content_type = "text/plain; charset=\"us-ascii\""
    content = templatefile("${path.module}/base_config.tftpl", {
      hostname         = "${local.prefix}fgt${count.index + 1}-${local.zone_short}"
      healthcheck_port = var.healthcheck_port
      # all private addresses for given instance. ordered by subnet/nic index0
      //prv_ips  = { for indx, addr in google_compute_address.prv : split("_", indx)[0] => addr.address if tonumber(split("_", indx)[1]) == count.index }
      prv_ips = {
        port1 = var.addresses["fgt${count.index + 1}"].data_prv
        port2 = var.addresses["fgt${count.index + 1}"].mgmt_prv
      }
      ilb_addr = var.xzone_ilb_addrs
      ## reverse indexing in case we wanted more subnets per port in future
      subnets = { for port, subnet in data.google_compute_subnetwork.connected :
        subnet.ip_cidr_range => {
          "dev" : port,
          "name" : subnet.name
        }
      }
      gateways = { for port, subnet in data.google_compute_subnetwork.connected : port => subnet.gateway_address }
      ha_indx  = count.index + local.ha_indx_zone_offset
      # each private address on last interface except for matching the instance index
      //ha_peers = [for key, addr in google_compute_address.prv : addr.address if tonumber(split("_", key)[1]) != count.index && split("_", key)[0] == local.fgsp_port]
      ha_peers = setunion(
        [for key, addr in var.addresses : addr.mgmt_prv if key != "fgt${count.index + 1}"],
        var.xzone_fgsp_peers
      )
      //frontends        = concat([for eip in var.frontends : try(local.eip_all[eip], local.eip_all[eip.name])], [for eipobj in var.frontends_obj : eipobj.address])
      frontends        = []
      nsi_port         = local.nsi_port
      mgmt_port        = local.mgmt_port
      mgmt_port_public = var.mgmt_port_public
      fortimanager     = var.fortimanager
      fgt_config       = var.fgt_config
    })
  }
}


#
# Find image either based on version+arch+lic ...
#
module "fgtimage" {
  count = var.fgt_image.version == "" ? 0 : 1

  source = "./modules/fgt-get-image"
  ver    = var.fgt_image.version
  arch   = var.fgt_image.arch
  lic    = "${try(var.license_files[0], "")}${try(var.flex_tokens[0], "")}" != "" ? "byol" : var.fgt_image.lic
}
# ... or based on family/name
data "google_compute_image" "by_family_name" {
  count = var.fgt_image.version == "" ? 1 : 0

  project = var.fgt_image.project
  family  = var.fgt_image.name == "" ? var.fgt_image.family : null
  name    = var.fgt_image.name != "" ? var.fgt_image.name : null

  lifecycle {
    postcondition {
      condition     = !(("${try(var.license_files[0], "")}${try(var.flex_tokens[0], "")}" != "") && strcontains(self.name, "ondemand"))
      error_message = "You provided a FortiGate BYOL (or Flex) license, but you're attempting to deploy a PAYG image. This would result in a double license fee. \nUpdate module's 'image' parameter to fix this error.\n\nCurrent var.image value: \n  {%{for k, v in var.fgt_image}%{if tostring(v) != ""}\n    ${k}=${v}%{endif}%{endfor}\n  }"
    }
  }
}
# ... and pick one
locals {
  fgt_image = var.fgt_image.version == "" ? data.google_compute_image.by_family_name[0] : module.fgtimage[0].image
}

#
# Deploy VMs
#
resource "google_compute_instance" "fgt_vm" {
  count = var.cluster_size

  zone           = var.zone
  name           = "${local.prefix}vm-${local.fgts[count.index]}-${local.zone_short}"
  machine_type   = var.machine_type
  can_ip_forward = true
  tags           = var.fgt_tags

  boot_disk {
    initialize_params {
      image  = local.fgt_image.self_link
      labels = var.labels
    }
  }
  attached_disk {
    source = var.logdisk_size > 0 ? google_compute_disk.logdisk[count.index].name : null
  }
  service_account {
    email  = local.service_account
    scopes = ["cloud-platform"]
  }
  metadata = {
    user-data          = data.cloudinit_config.fgt[count.index].rendered
    license            = fileexists(try(var.license_files[count.index], "null")) ? file(var.license_files[count.index]) : null
    serial-port-enable = var.serial_port_enable
    oslogin-enable     = var.oslogin_enable
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.connected["port1"].name
    nic_type   = local.nic_type
    network_ip = var.addresses[local.fgts[count.index]].data_prv
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.connected["port2"].name
    nic_type   = local.nic_type
    network_ip = var.addresses[local.fgts[count.index]].mgmt_prv
    dynamic "access_config" {
      for_each = var.mgmt_port_public ? [1] : []
      content {
        nat_ip = var.addresses[local.fgts[count.index]].mgmt_pub
      }
    }
  }
  /*
  dynamic "network_interface" {
    for_each = data.google_compute_subnetwork.connected

    content {
      subnetwork = network_interface.value.name
      nic_type   = local.nic_type
      network_ip = google_compute_address.prv["${network_interface.key}_${count.index}"].address
      dynamic "access_config" {
        for_each = var.mgmt_port_public && local.mgmt_port == network_interface.key ? [1] : []
        content {
          nat_ip = google_compute_address.mgmt[local.fgts[count.index]].address
        }
      }
    }
  }
*/
} //fgt-vm

#
# Common Load Balancer resources
#
resource "google_compute_region_health_check" "health_check" {
  name               = "${local.prefix}healthcheck-http${var.healthcheck_port}-${local.zone_short}"
  region             = local.region
  timeout_sec        = 2
  check_interval_sec = 2

  http_health_check {
    port = var.healthcheck_port
  }
}
/*
resource "google_compute_instance_group" "fgt_umig" {
  name      = "${local.prefix}umig-${local.zone_short}"
  zone      = var.zone
  instances = google_compute_instance.fgt_vm[*].self_link
}
*/

resource "google_compute_instance_group_membership" "fgts_umig" {
  count          = var.cluster_size
  zone           = var.zone
  instance       = google_compute_instance.fgt_vm[count.index].id
  instance_group = var.fgt_umig
}
