locals {
  prefix = var.prefix
}


module "vpc_prod_data" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id   = var.project_id
  network_name = "${local.prefix}-prod"
  routing_mode = "GLOBAL"

  subnets = [{
    subnet_name           = "${local.prefix}-prod-euw1"
    subnet_ip             = "10.0.0.0/24"
    subnet_region         = var.region
    subnet_private_access = "true"
  }]

  ingress_rules = [{
    name          = "${var.prefix}-prod-allowall"
    source_ranges = ["0.0.0.0/0"]
    allow = [{
      protocol = "all"
    }]
  }]
}

module "vpc_prod_mgmt" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id   = var.project_id
  network_name = "${local.prefix}-mgmt"
  routing_mode = "GLOBAL"

  subnets = [{
    subnet_name           = "${local.prefix}-mgmt-euw1"
    subnet_ip             = "10.0.1.0/24"
    subnet_region         = var.region
    subnet_private_access = "true"
  }]
}

resource "google_compute_address" "psc_fmg" {
  name         = "${var.prefix}-psc-fmg"
  address_type = "INTERNAL"
  subnetwork   = module.vpc_prod_mgmt.subnets["${var.region}/${local.prefix}-mgmt-euw1"].name
  region       = var.region
}

resource "google_compute_forwarding_rule" "psc_fmg" {
  name                    = "${var.prefix}-psc-fmg"
  region                  = var.region
  ip_address              = google_compute_address.psc_fmg.id
  network                 = module.vpc_prod_mgmt.network_name
  target                  = "projects/se-projects-242100/regions/europe-west1/serviceAttachments/bm-fmg"
  allow_psc_global_access = true
  load_balancing_scheme   = ""
}

module "producer" {
  source     = "./modules/producer"
  prefix     = var.prefix
  project_id = var.project_id
  networks = {
    data = {
      subnet_name = module.vpc_prod_data.subnets_names[0],
      network_id  = module.vpc_prod_data.network_id
    },
    mgmt = {
      subnet_name = module.vpc_prod_mgmt.subnets_names[0]
    }
  }
  zones = [
    "${var.region}-b",
    "${var.region}-c"
  ]
  flex_tokens = [for serial in local.flex_serials : fortiflexvm_entitlements_vm_token.fgts[serial].token]
  fortimanager = {
    ip     = "fmg2.gcp.40net.cloud" //google_compute_address.psc_fmg.address
    serial = "FMVMELTM23000032"
  }
  depends_on = [
    module.vpc_prod_data,
    module.vpc_prod_mgmt
  ]
}


module "consumer" {
  source              = "./modules/consumer"
  prefix              = "${var.prefix}-consumer1"
  project_id          = var.project_id
  deployment_group_id = module.producer.deployment_group.id
  zones = [
    "${var.region}-b",
    "${var.region}-c"
  ]
  region = var.region
}


