terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
    fortiflexvm = {
      source = "fortinetdev/fortiflexvm"
    }
  }
  /*
  cloud {
    organization = "40net"
    workspaces {
      name = "NSI"
    }
  }
  */
}

provider "google" {
  project = var.prod_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.prod_project_id
  region  = var.region
  user_project_override = true
  billing_project       = var.prod_project_id
}
