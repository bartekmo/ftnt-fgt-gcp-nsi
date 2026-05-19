# 
# Deploy two VMs into the same subnet
# 
resource "google_compute_instance" "vm1" {
  name         = "${var.prefix}-vm1"
  zone         = var.zones[0]
  project      = var.project_id
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }
  network_interface {
    subnetwork = module.vpc.subnets["${var.region}/${var.prefix}-consumer1-euw1"].id
    access_config {}
  }
  tags = ["ssh"]
}

resource "google_compute_instance" "vm2" {
  name    = "${var.prefix}-vm2"
  zone    = var.zones[0]
  project = var.project_id

  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }
  network_interface {
    subnetwork = module.vpc.subnets["${var.region}/${var.prefix}-consumer1-euw1"].id
  }
  tags = ["ssh"]
}
