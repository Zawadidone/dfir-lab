locals {
  api_services = [
    "compute.googleapis.com",
    "file.googleapis.com",
    "certificatemanager.googleapis.com",
  ]
}

resource "google_project_service" "api_services" {
  count              = length(local.api_services)
  project            = var.gcp_project
  service            = local.api_services[count.index]
  disable_on_destroy = false
}

resource "google_compute_subnetwork" "velociraptor" {
  name          = "velociraptor"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = var.gcp_network
  private_ip_google_access = true
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "${var.project_name}-velociraptor"
  target                = google_compute_target_https_proxy.default.id
  ip_address            = var.gcp_lb_ip_address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.project_name}-velociraptor"

  managed {
    domains = [var.domain_name]
 }
}

resource "google_compute_target_https_proxy" "default" {
  name     = "${var.project_name}-velociraptor"
  url_map  = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_url_map" "default" {
  name            = "${var.project_name}-velociraptor"
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts = [var.domain_name]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service =  google_compute_backend_service.frontend.id
    
    path_rule {
      paths = ["/*"]
      service =  google_compute_backend_service.frontend.id
    }
    
    path_rule {
      paths = ["/gui/*"]
      service =  google_compute_backend_service.gui.id
    }
  }
}

resource "google_compute_backend_service" "frontend" {
  name                     = "${var.project_name}-velociraptor-frontend"
  protocol                 = "HTTP"
  port_name                = "http"
  load_balancing_scheme    = "EXTERNAL_MANAGED"
  timeout_sec              = 10
  health_checks            = [google_compute_health_check.default.id]

  backend {
    description = "This backend serves the Velociraptor frontend"
    balancing_mode  = "UTILIZATION"
    group           = google_compute_region_instance_group_manager.default.instance_group # change to minions instance group if used
    capacity_scaler = 1.0
  }
  
  log_config {
    enable = true
  }
}

resource "google_compute_backend_service" "gui" {
  name                     = "${var.project_name}-velociraptor-gui"
  provider                 = google-beta
  protocol                 = "HTTP"
  port_name                = "http"
  load_balancing_scheme    = "EXTERNAL_MANAGED"
  timeout_sec              = 10
  health_checks            = [google_compute_health_check.default.id]

  backend {
    description = "This backend serves the Velociraptor GUI by the single master"
    group           = google_compute_region_instance_group_manager.default.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable = true
  }
}

resource "random_password" "velociraptor_password" {
  length           = 16
}

data "template_file" "velociraptor_master_install" {
  template = file("${path.module}/templates/scripts/install-velociraptor.sh.tpl")

  vars = {
    version               = var.velociraptor_version
    domain_name           = var.domain_name
    hostname              = var.velociraptor_master_ip_address
    password              = random_password.velociraptor_password.result
    bucket_uri            = google_storage_bucket.default.url
    file_store_location   = "/var/tmp/velociraptor"
    file_share_ip_address = google_filestore_instance.default.networks[0].ip_addresses[0]
    file_share_name       =  google_filestore_instance.default.file_shares[0].name
  }
}

resource "google_service_account" "default" {
  account_id   = "${var.project_name}-velociraptor"
}

resource "google_storage_bucket_iam_member" "creator" {
  bucket = google_storage_bucket.default.name
  role = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.default.email}"
}

resource "google_storage_bucket_iam_member" "writer" {
  bucket = google_storage_bucket.default.name
  role = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:${google_service_account.default.email}"
}

resource "google_compute_instance_template" "default" {
  name_prefix  = "${var.project_name}-velociraptor-master-"
  machine_type = var.gcp_machine_type
  tags         = ["allow-health-check", "allow-iap"]

  metadata_startup_script = data.template_file.velociraptor_master_install.rendered

  depends_on = [
    google_project_service.api_services, 
    google_compute_subnetwork.velociraptor, 
    google_filestore_instance.default,
    google_storage_bucket.default,
    google_service_account.default
  ]

  service_account {
    scopes = ["storage-rw"] # needed for gsutil upload from startup script
  }
  
  network_interface {
    subnetwork =  google_compute_subnetwork.velociraptor.id
    network_ip = var.velociraptor_master_ip_address
  }

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    disk_size_gb  = "20"
    disk_type = "pd-ssd"
    type = "PERSISTENT"
    auto_delete = false
    boot = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance   = "MIGRATE"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "default" {
  name     = "${var.project_name}-velociraptor"

  http_health_check {
    port = 8080
    request_path = "/server.pem"
  }

  log_config {
    enable = true
  }
}

### If the multi Velociraptor setup is used another instance group should be created for the minions only which receives traffic from the frontend service
resource "google_compute_region_instance_group_manager" "default" {
  name     = "${var.project_name}-velociraptor"
  base_instance_name = "${var.project_name}-velociraptor-master"
  target_size        = 1 # don't increase their is only one Velociraptor master
  
  named_port {
    name = "http"
    port = 8080
  }

  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }
}

resource "google_compute_firewall" "default" {
  name          = "${var.project_name}-velociraptor-allow-health-check"
  direction     = "INGRESS"
  network       = var.gcp_network
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  target_tags = ["allow-health-check"]
}

resource "google_compute_firewall" "iap" {
  name          = "${var.project_name}-velociraptor-allow-iap"
  direction     = "INGRESS"
  network       = var.gcp_network
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["allow-iap"]
}

resource "google_filestore_instance" "default" {
  name           = "${var.project_name}-velociraptor"
  provider = google-beta
  description = "The filestore used by the Velociraptor master and minions"
  tier = "BASIC_HDD" # use HIGH_SCALE_SSD or BASIC_SSD for production https://cloud.google.com/filestore/docs/creating-instances#allocating_capacity
  location = var.gcp_zone

  depends_on = [google_project_service.api_services, google_compute_subnetwork.velociraptor]

  file_shares {
    name = "file_store"
    capacity_gb = var.velociraptor_file_store_size

    nfs_export_options {
      ip_ranges = ["10.0.0.0/24"]
    } 
  }

  networks {
    network = var.project_name 
    modes   = ["MODE_IPV4"]
    reserved_ip_range = "10.0.1.0/29"
  }
}

resource "google_storage_bucket" "default" {
  name          = "${var.project_name}-velociraptor"
  location      = var.gcp_region
  storage_class = "STANDARD"
  force_destroy = true
}
