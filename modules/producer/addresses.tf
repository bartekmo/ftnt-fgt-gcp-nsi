

#
# Reserve a private address for each subnet * for each instance
#
## Indexed by port name * FGT instance index (port1_0, port1_1, port2_0, port2_1, ...)
# 
resource "google_compute_address" "mgmt_prv" {
  for_each = local.zone_x_indx

  name         = "${local.prefix}addr2-mgmt-${each.value.fgt}-${local.zones_short[each.value.zone]}"
  region       = local.regions[each.value.zone]
  address_type = "INTERNAL"
  subnetwork   = var.networks.mgmt.subnet_name
}

resource "google_compute_address" "data_prv" {
  for_each = local.zone_x_indx

  name         = "${local.prefix}addr2-data-${each.value.fgt}-${local.zones_short[each.value.zone]}"
  region       = local.regions[each.value.zone]
  address_type = "INTERNAL"
  subnetwork   = var.networks.data.subnet_name
}

#
# Reserve a public IP for each FGT instance (if enabled in var.mgmt_port_public)
#
resource "google_compute_address" "mgmt_pub" {
  for_each = var.mgmt_port_public ? local.zone_x_indx : {}

  name   = "${local.prefix}addr2-mgmtpub-${each.value.fgt}-${local.zones_short[each.value.zone]}"
  region = local.regions[each.value.zone]
}

#
# Reserve address for ILB -  keeping the structure dynamic, but with static list of 1 defined in locals
# 
## Indexed by port name (port2, ...)
# 
resource "google_compute_address" "ilb" {
  for_each = toset(var.zones)

  name         = "${local.prefix}addr2-ilb-${local.zones_short[each.key]}"
  region       = local.regions[each.key]
  address_type = "INTERNAL"
  subnetwork   = var.networks.data.subnet_name
}
