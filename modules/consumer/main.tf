/*resource "google_network_security_firewall_endpoint" "default" {
  for_each           = toset(var.zones)
  name               = "${var.prefix}-fwe-${each.value}"
  parent             = "organizations/529833491623"
  location           = each.value
  billing_project_id = "forti-emea-se"

  labels = {
    foo = "bar"
  }
}*/

resource "google_network_security_intercept_endpoint_group" "fgt" {
  provider                    = google-beta
  intercept_endpoint_group_id = "${var.prefix}-ieg"
  location                    = "global"
  intercept_deployment_group  = var.deployment_group_id
  description                 = "some description"
  labels = {
    foo = "bar"
  }
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id                                = var.project_id
  network_name                              = var.prefix
  routing_mode                              = "GLOBAL"
  network_firewall_policy_enforcement_order = "BEFORE_CLASSIC_FIREWALL"

  subnets = [{
    subnet_name   = "${var.prefix}-consumer1-euw1"
    subnet_ip     = "192.168.101.0/24"
    subnet_region = var.region
    },
    /*  {
    subnet_name = "${local.prefix}-consumer1-euw8"
    subnet_ip     = "192.168.108.0/24"
    subnet_region = "europe-west8"
  } */
  ]

  ingress_rules = [{
    name          = "${var.prefix}-iap-ssh"
    source_ranges = ["35.235.240.0/20"]
    target_tags   = ["ssh"]
    allow = [{
      protocol = "TCP"
      ports    = ["22"]
    }]
  }]
}


resource "google_network_security_intercept_endpoint_group_association" "fgt" {
  provider                                = google-beta
  intercept_endpoint_group_association_id = "${var.prefix}-iega"
  location                                = "global"
  network                                 = module.vpc.network_id
  intercept_endpoint_group                = google_network_security_intercept_endpoint_group.fgt.id
}

resource "google_network_security_security_profile" "fgt" {
  provider    = google-beta
  name        = "${var.prefix}-sp"
  parent      = "organizations/529833491623"
  description = "FortiGate NSI demo"
  type        = "CUSTOM_INTERCEPT"

  custom_intercept_profile {
    intercept_endpoint_group = google_network_security_intercept_endpoint_group.fgt.id
  }
}

resource "google_network_security_security_profile_group" "fgt" {
  provider                 = google-beta
  name                     = "${var.prefix}-spg"
  parent                   = "organizations/529833491623"
  description              = "my description"
  custom_intercept_profile = google_network_security_security_profile.fgt.id
}

resource "google_compute_network_firewall_policy" "fgt_nsi" {
  name = "${var.prefix}-fp"
}

resource "google_compute_network_firewall_policy_association" "default" {
  name              = module.vpc.network_name
  attachment_target = module.vpc.network_id
  firewall_policy   = google_compute_network_firewall_policy.fgt_nsi.id
}

resource "google_compute_network_firewall_policy_rule" "inspect_in" {
  provider               = google-beta
  action                 = "apply_security_profile_group"
  direction              = "INGRESS"
  disabled               = false
  enable_logging         = true
  security_profile_group = google_network_security_security_profile_group.fgt.id
  firewall_policy        = google_compute_network_firewall_policy.fgt_nsi.name
  priority               = 100
  rule_name              = "${var.prefix}-intercept-in"

  match {
    src_ip_ranges = ["192.168.0.0/16"]

    layer4_configs {
      ip_protocol = "all"
    }
  }
}

/*
resource "google_compute_network_firewall_policy_rule" "inspect_out" {
  provider               = google-beta
  action                 = "apply_security_profile_group"
  direction              = "EGRESS"
  disabled               = true
  enable_logging         = true
  security_profile_group = google_network_security_security_profile_group.fgt.id
  firewall_policy        = google_compute_network_firewall_policy.fgt_nsi.name
  priority               = 101
  rule_name              = "${var.prefix}-intercept-out"

  match {
    dest_ip_ranges = ["192.168.0.0/16"]

    layer4_configs {
      ip_protocol = "all"
    }
  }
} */
/*
resource "google_compute_network_firewall_policy_rule" "iperf" {
  provider        = google-beta
  action          = "allow"
  direction       = "INGRESS"
  disabled        = false
  enable_logging  = true
  firewall_policy = google_compute_network_firewall_policy.fgt_nsi.name
  priority        = 91
  rule_name       = "${var.prefix}-test"

  match {
    src_ip_ranges = ["192.168.0.0/16"]

    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["5201", "5001"]
    }
  }
}
*/
resource "google_compute_network_firewall_policy_rule" "apt" {
  provider               = google-beta
  action                 = "apply_security_profile_group"
  direction              = "EGRESS"
  disabled               = false
  enable_logging         = true
  firewall_policy        = google_compute_network_firewall_policy.fgt_nsi.name
  security_profile_group = "//networksecurity.googleapis.com/${google_network_security_security_profile_group.fgt.id}"
  priority               = 80
  rule_name              = "${var.prefix}-apt"

  match {
    dest_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["80", "443"]
    }
  }
}

output "test" {
  value = google_network_security_security_profile_group.fgt
}
