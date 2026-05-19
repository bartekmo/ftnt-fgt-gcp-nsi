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

# 
# Intercept Deployment Group is the entry point for NSI producer aggregating all zonal intercept deployments. 
# 
resource "google_network_security_intercept_deployment_group" "fgt" {
  intercept_deployment_group_id = "${var.prefix}-idg"
  provider                      = google-beta
  location                      = "global"
  network                       = var.networks.data.network_id
}

# 
# NSI producer consists of one or more zonal sets of resources. 
# Create one for each zone
# 
module "intercept_zones" {
  for_each = toset(var.zones)
  source   = "../fgt-producer-zone"

  prefix                        = var.prefix
  zone                          = each.key
  intercept_deployment_group_id = google_network_security_intercept_deployment_group.fgt.id
  cluster_size                  = var.cluster_size_per_zone
  machine_type                  = var.machine_type
  # FortiGate image link is obtained using the same submodule as in HA modules
  fgt_image_url = local.fgt_image.self_link
  # at the moment this module supports only FortiFlex licensing
  # TODO: other licensing types
  flex_tokens = var.flex_tokens == null ? null : slice(var.flex_tokens,
    index(var.zones, each.key) * var.cluster_size_per_zone,
  (index(var.zones, each.key) + 1) * var.cluster_size_per_zone)
  fortimanager = var.fortimanager
  # each FortiGate will have 2 NICs used for data and for management
  subnets = [
    var.networks.data.subnet_name,
    var.networks.mgmt.subnet_name,
  ]

  addresses = { for key, val in local.zone_x_indx : val.fgt => {
    mgmt_prv : google_compute_address.mgmt_prv[key].address
    mgmt_pub : var.mgmt_port_public ? google_compute_address.mgmt_pub[key].address : null
    data_prv : google_compute_address.data_prv[key].address
  } if val.zone == each.key }
  ilb_address = google_compute_address.ilb[each.key].address
  # Instance groups are created in global producer module, so we can pass them as failback between different zones
  fgt_umig = google_compute_instance_group.fgt_umigs[each.key].id

  # zonal intercept deployments are configured to accept traffic from other zones in case all FortiGates in primary zones are unhealthy
  xzone_fallback_umigs = [for zone in setsubtract(var.zones, [each.key]) : google_compute_instance_group.fgt_umigs[zone].id if join("-", slice(split("-", zone), 0, 2)) == join("-", slice(split("-", each.key), 0, 2))] //for zone in setsubstract(var.zones, [each.key]) : module.intercept_zones[zone].fgt_umig] //for zone in var.zones : module.intercept_zones[zone].fgt_umig if zone != each.key]
  xzone_fgsp_peers     = [for key, val in local.zone_x_indx : google_compute_address.mgmt_prv[key].address if val.zone != each.key]
  xzone_ilb_addrs      = [for zone in var.zones : google_compute_address.ilb[zone].address if join("-", slice(split("-", zone), 0, 2)) == join("-", slice(split("-", each.key), 0, 2))]
}

#
# Find FortiGate image either based on version+arch+lic ...
#
module "fgtimage" {
  count = var.fgt_image.version == "" ? 0 : 1

  source = "../fgt-get-image"
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



