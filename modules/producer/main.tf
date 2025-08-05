locals {
  prefix        = length(var.prefix) > 0 && substr(var.prefix, -1, 1) != "-" ? "${var.prefix}-" : var.prefix
  regions       = { for zone in var.zones : zone => join("-", slice(split("-", zone), 0, 2)) }
  regions_short = { for zone in var.zones : zone => replace(replace(replace(replace(replace(replace(replace(replace(replace(local.regions[zone], "-south", "s"), "-east", "e"), "-central", "c"), "-north", "n"), "-west", "w"), "europe", "eu"), "australia", "au"), "northamerica", "na"), "southamerica", "sa") }
  zones_short   = { for zone in var.zones : zone => "${local.regions_short[zone]}${substr(zone, length(local.regions[zone]) + 1, 1)}" }

  zone_x_indx = {
    for pair in setproduct(var.zones, range(var.cluster_size_per_zone)) :
    join("_", pair) => {
      zone : pair[0],
      indx : pair[1]
      fgt : "fgt${pair[1] + 1}"
    }
  }
}

resource "google_network_security_intercept_deployment_group" "fgt" {
  intercept_deployment_group_id = "${var.prefix}-idg"
  provider                      = google-beta
  location                      = "global"
  network                       = var.networks.data.network_id
}


module "intercept_zones" {
  for_each = toset(var.zones)
  source   = "../fgt-nsi-zone"

  prefix                        = var.prefix
  zone                          = each.key
  intercept_deployment_group_id = google_network_security_intercept_deployment_group.fgt.id
  cluster_size                  = var.cluster_size_per_zone
  machine_type                  = "e2-standard-2"
  fgt_image = {
    version = "7.6.3"
    license = var.flex_tokens == null ? "PAYG" : "BYOL"
  }
  flex_tokens = var.flex_tokens == null ? null : slice(var.flex_tokens,
    index(var.zones, each.key) * var.cluster_size_per_zone,
  (index(var.zones, each.key) + 1) * var.cluster_size_per_zone)
  fortimanager = var.fortimanager
  subnets = [
    var.networks.data.subnet_name,
    var.networks.mgmt.subnet_name,
  ]

  addresses = { for key, val in local.zone_x_indx : val.fgt => {
    mgmt_prv : google_compute_address.mgmt_prv[key].address
    mgmt_pub : var.mgmt_port_public ? google_compute_address.mgmt_pub[key].address : null
    data_prv : google_compute_address.data_prv[key].address
  } if val.zone == each.key }
  ilb_address          = google_compute_address.ilb[each.key].address
  fgt_umig             = google_compute_instance_group.fgt_umigs[each.key].id
  xzone_fallback_umigs = [for zone in setsubtract(var.zones, [each.key]) : google_compute_instance_group.fgt_umigs[zone].id if join("-", slice(split("-", zone), 0, 2)) == join("-", slice(split("-", each.key), 0, 2))] //for zone in setsubstract(var.zones, [each.key]) : module.intercept_zones[zone].fgt_umig] //for zone in var.zones : module.intercept_zones[zone].fgt_umig if zone != each.key]
  xzone_fgsp_peers     = [for key, val in local.zone_x_indx : google_compute_address.mgmt_prv[key].address if val.zone != each.key]
  xzone_ilb_addrs      = [for zone in var.zones : google_compute_address.ilb[zone].address if join("-", slice(split("-", zone), 0, 2)) == join("-", slice(split("-", each.key), 0, 2))]
}

