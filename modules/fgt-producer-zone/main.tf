terraform {
  required_version = ">= 1.1.0"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
  }
}

data "google_compute_default_service_account" "default" {}

data "google_client_config" "default" {}

data "google_compute_zones" "zones_in_region" {
  region = local.region
}

#
# Apply defaults if not overriden in variables, sanitize inputs
#
locals {
  # if service account is not passed explicitly in variable, pick the default Compute Engine account
  service_account = coalesce(var.service_account, data.google_compute_default_service_account.default.email)

  # derive region from zones if provided, otherwise use the region from variable, as last resort use default region from provider
  region = join("-", slice(split("-", var.zone), 0, 2))

  #sanitize labels
  labels = { for k, v in var.labels : k => replace(lower(v), " ", "_") }

  # If prefix is defined, add a "-" spacer after it
  prefix = length(var.prefix) > 0 && substr(var.prefix, -1, 1) != "-" ? "${var.prefix}-" : var.prefix

  # Auto-set NIC type to GVNIC if ARM image was selected
  nic_type = var.nic_type # strcontains(var.fgt_image_url, "arm64") ? "GVNIC" : var.nic_type

  # Calculate last port for management or copy from vars. Used for FGT configuration bootstrap, ACL, and public IPs. 
  mgmt_port = var.mgmt_port != null ? var.mgmt_port : "port2"

  # Calculate FGSP port (last one) if set to "auto", otherwise use variable. Null means no dedicated port => FGSP over port1.
  fgsp_port = var.fgsp_port
  nsi_port  = "port1"

  #
  # Create common lists
  #
  hc_ranges_ilb = ["35.191.0.0/16", "130.211.0.0/22"]
  hc_ranges_elb = ["35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]

  fgts = [for indx in range(var.cluster_size) : "fgt${indx + 1}"]

  # calculate FGT HA index offset for the zone
  ha_indx_zone_offset = (index(data.google_compute_zones.zones_in_region.names, var.zone) + 1) * var.cluster_size
}


# 
# Pull information about subnets we will connect to FortiGate instances. Subnets must
# already exist (can be created in parent module).
# Index by port name
#
data "google_compute_subnetwork" "connected" {
  for_each = toset([for indx in range(length(var.subnets)) : "port${indx + 1}"]) #toset(var.subnets)
  name     = var.subnets[substr(each.value, 4, 1) - 1]
  region   = local.region
}

#
# We'll use shortened region and zone names for some resource names. This is a standard shortening described in
# GCP security foundations.
#
locals {
  region_short = replace(replace(replace(replace(replace(replace(replace(replace(replace(local.region, "-south", "s"), "-east", "e"), "-central", "c"), "-north", "n"), "-west", "w"), "europe", "eu"), "australia", "au"), "northamerica", "na"), "southamerica", "sa")
  zone_short   = "${local.region_short}${substr(var.zone, length(local.region) + 1, 1)}"
}


