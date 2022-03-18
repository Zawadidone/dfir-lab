terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.8.0"
    }
    ec = {
      source = "elastic/ec"
      version = "0.4.0"
    }
  }
}

provider "ec" {
  apikey = var.elastic_cloud_api_key
}


provider "google" {
  project     = var.gcp_project
  region      = var.gcp_region
}

