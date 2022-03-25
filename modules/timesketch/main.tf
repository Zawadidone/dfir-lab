locals {
  api_services = [
    "compute.googleapis.com",
    "file.googleapis.com",
    "certificatemanager.googleapis.com",
    "servicedirectory.googleapis.com",
    "dns.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
}

resource "google_project_service" "api_services" {
  count              = length(local.api_services)
  project            = var.gcp_project
  service            = local.api_services[count.index]
  disable_on_destroy = false
}

resource "google_compute_subnetwork" "default" {
  name          = "timesketch"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.gcp_region
  network       = var.gcp_network
  private_ip_google_access = true
}


resource "google_sql_database" "default" {
  name     = "timesketch"
  instance = google_sql_database_instance.default.name
}

resource "random_string" "timesketch_db_password" {
  length = 16
  special = false
}

resource "google_sql_user" "default" {
  name     = "timesketch"
  instance = google_sql_database_instance.default.name
  password = random_string.timesketch_db_password.result
}

resource "random_string" "sql_random" {
  length           = 4
  min_lower        = 4
}

resource "google_sql_database_instance" "default" {
  # The Cloud SQL instance already exists. When you delete an instance, you can't reuse the name of the deleted instance until one week from the deletion date
  name              = "${var.project_name}-timesketch-${random_string.sql_random.result}"
  region            = var.gcp_region
  database_version  = "POSTGRES_9_6"
  depends_on        = [google_project_service.api_services, google_service_networking_connection.default]
  deletion_protection = false

  settings {
    tier = "db-f1-micro"
    activation_policy = "ALWAYS"
    disk_autoresize = true

    ip_configuration {
      require_ssl = false
      ipv4_enabled = false
      private_network = var.gcp_network
      #authorized_networks {}
    }
  }
}

resource "google_redis_instance" "default" {
  name           = "${var.project_name}-timesketch"
  memory_size_gb = 1 
  tier = "STANDARD_HA" 
  authorized_network = var.gcp_network
  depends_on        = [google_project_service.api_services]
}


resource "google_filestore_instance" "default" {
  name           = "${var.project_name}-timesketch-upload"
  provider = google-beta
  project = var.gcp_project
  description = "The filestore used by Timesketch web and workers"
  tier = "BASIC_SSD"
  location = var.gcp_zone

  depends_on = [google_project_service.api_services, google_compute_subnetwork.default]

  file_shares {
    name = "file_store"
    capacity_gb = var.file_store_size

    nfs_export_options {
      ip_ranges =  [google_compute_subnetwork.default.ip_cidr_range]
    } 
  }
  networks {
    network = var.project_name
    modes   = ["MODE_IPV4"]
    reserved_ip_range = "10.0.3.0/29"
  }
}


resource "google_compute_global_forwarding_rule" "default" {
  name                  = "${var.project_name}-timesketch"
  target                = google_compute_target_https_proxy.default.id
  ip_address            = var.gcp_lb_ip_address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.project_name}-timesketch"

  managed {
    domains = [var.domain_name]
 }
}

resource "google_compute_target_https_proxy" "default" {
  name     = "${var.project_name}-timesketch"
  url_map  = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_url_map" "https" {
  name            = "${var.project_name}-timesketch"
  default_service = google_compute_backend_service.default.id

  host_rule {
    hosts = [var.domain_name] 
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service =  google_compute_backend_service.default.id
    
    path_rule {
      paths = ["/*"]
      service =  google_compute_backend_service.default.id
    }
  }
}

resource "google_compute_backend_service" "default" {
  name                     = "${var.project_name}-timesketch"
  protocol                 = "HTTP"
  port_name                = "http"
  load_balancing_scheme    = "EXTERNAL_MANAGED"
  timeout_sec              = 10
  health_checks            = [google_compute_health_check.default.id]

  custom_response_headers         = ["X-Forwarded-Proto: https"]
  backend {
    description = "This backend serves Timesketch web"
    balancing_mode  = "UTILIZATION"
    group           = google_compute_region_instance_group_manager.web.instance_group
    capacity_scaler = 1.0
  }
  
  log_config {
    enable = true
  }
}

resource "google_compute_region_instance_group_manager" "web" {
  name     = "${var.project_name}-timesketch-web"
  base_instance_name = "${var.project_name}-timesketch-web"
  target_size        = var.web_target_size
  
  named_port {
    name = "http"
    port = 5000
  }

  version {
    instance_template = google_compute_instance_template.web.id
    name              = "primary"
  }

}

resource "google_compute_region_instance_group_manager" "worker" {
  name     = "${var.project_name}-timesketch-worker"
  base_instance_name = "${var.project_name}-timesketch-worker"
  target_size        = var.worker_target_size
  
  version {
    instance_template = google_compute_instance_template.worker.id
    name              = "primary"
  }
}

resource "random_string" "timesketch_admin_password" {
  length = 16
  special = false
}

resource "random_string" "timesketch_secret_key" {
  length = 32
  special = false
}

data "template_file" "configuration" {
  template = file("${path.module}/templates/configuration/timesketch.conf.tpl")
  vars = {
      secret_key = random_string.timesketch_secret_key.result
      postgres_user           = google_sql_user.default.name
      postgres_host           = google_sql_database_instance.default.first_ip_address
      postgres_db             = google_sql_database.default.name
      postgres_password       = random_string.timesketch_db_password.result
      postgres_port           = 5432
      opensearch_host = regex("(?:[A-Za-z0-9-]+\\.)+[A-Za-z0-9]{1,3}", ec_deployment.default.elasticsearch[0].https_endpoint)
      opensearch_port         = 9243
      opensearch_user         = ec_deployment.default.elasticsearch_username
      opensearch_password     = ec_deployment.default.elasticsearch_password
      redis_host                = google_redis_instance.default.host
      redis_port                = google_redis_instance.default.port
    }
}

data "template_file" "web" {
  template = file("${path.module}/templates/scripts/install-timesketch-web.sh.tpl")
  vars = {
    timesketch_configuration = data.template_file.configuration.rendered
    timesketch_version                   = var.timesketch_version
    timesketch_admin_password = var.timesketch_password 
    file_share_ip_address     = google_filestore_instance.default.networks[0].ip_addresses[0]
    file_share_name           =  google_filestore_instance.default.file_shares[0].name
  }
}

data "template_file" "worker" {
  template = file("${path.module}/templates/scripts/install-timesketch-worker.sh.tpl")
  vars = {
    timesketch_configuration = data.template_file.configuration.rendered
    timesketch_version                   = var.timesketch_version
    timesketch_admin_password = var.timesketch_password 
    file_share_ip_address     = google_filestore_instance.default.networks[0].ip_addresses[0]
    file_share_name           =  google_filestore_instance.default.file_shares[0].name
  }
}

resource "google_compute_instance_template" "web" {
  name_prefix  = "${var.project_name}-timesketch-web"
  machine_type = var.gcp_machine_type_web
  tags         = ["allow-health-check", "allow-iap"]

  metadata_startup_script = data.template_file.web.rendered

  depends_on = [
    google_project_service.api_services, 
    google_compute_subnetwork.default,
    google_filestore_instance.default,
    ec_deployment.default,
    google_sql_database_instance.default,
    google_redis_instance.default
  ]

  network_interface {
    subnetwork =  google_compute_subnetwork.default.id
  }

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    disk_size_gb  = "20"
    disk_type = "pd-ssd"
    type = "PERSISTENT"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance   = "MIGRATE"
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  # logging driver
  service_account {
    scopes = ["cloud-platform"]
  }
}


resource "google_compute_instance_template" "worker" {
  name_prefix  = "${var.project_name}-timesketch-worker"
  machine_type = var.gcp_machine_type_worker
  tags         = ["allow-iap"]

  metadata_startup_script = data.template_file.worker.rendered

  depends_on = [
    google_project_service.api_services, 
    google_compute_subnetwork.default,
    google_filestore_instance.default,
    ec_deployment.default,
    google_sql_database_instance.default,
    google_redis_instance.default
  ]

  network_interface {
    subnetwork =  google_compute_subnetwork.default.id
  }

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    disk_size_gb  = "20"
    disk_type = "pd-ssd"
    type = "PERSISTENT"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance   = "MIGRATE"
  }
  
  lifecycle {
    create_before_destroy = true
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_health_check" "default" {
  name     = "${var.project_name}-timesketch"

  http_health_check {
    port = 5000
    request_path = "/login/"
  }

  log_config {
    enable = true
  }
}

resource "google_compute_firewall" "default" {
  name          = "${var.project_name}-timesketch-allow-health-check"
  direction     = "INGRESS"
  network       = var.gcp_network
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  
  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  target_tags = ["allow-health-check"]
}

resource "google_compute_firewall" "iap" {
  name          = "${var.project_name}-timesketch-allow-iap"
  direction     = "INGRESS"
  network       = var.gcp_network
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["allow-iap"]
}


resource "google_compute_address" "elastic" {
    name   = "psc-ilb-consumer-address"
    depends_on = [google_compute_subnetwork.default]
    region = var.gcp_region
    subnetwork   = "timesketch"
    address_type = "INTERNAL"
  }
  
resource "google_compute_forwarding_rule" "elastic" {
  name   = "psc-ilb-consumer-forwarding-rule"
  region = var.gcp_region

  target                = "projects/cloud-production-168820/regions/europe-west4/serviceAttachments/proxy-psc-production-europe-west4-v1-attachment"
  load_balancing_scheme = "" # need to override EXTERNAL default when target is a service attachment
  network               = var.gcp_network
  ip_address            = google_compute_address.elastic.id
}
  
resource "google_dns_managed_zone" "elastic" {
  name        = "${var.project_name}-elastic"
  dns_name    = "${var.gcp_region}.gcp.elastic-cloud.com."
  description = "Example private DNS zone"
  visibility = "private"
  depends_on        = [google_project_service.api_services]
  
  private_visibility_config {
    networks {
      network_url = var.gcp_network
    }
  }
}
  
resource "google_dns_record_set" "elastic" {
  name = "*.${google_dns_managed_zone.elastic.dns_name}"
  managed_zone = google_dns_managed_zone.elastic.name
  type = "A"
  ttl = 300
  rrdatas = [google_compute_address.elastic.address]
}
  
data "ec_stack" "default" {
  version_regex = "7.?.?"
  region        = "gcp-${var.gcp_region}"
}
  
resource "ec_deployment" "default" {
  name                   = "${var.project_name}"
  provider               = ec
  region                 = "gcp-${var.gcp_region}"
  version                = data.ec_stack.default.version
  deployment_template_id = "gcp-compute-optimized"
  #traffic_filter        = [ec_deployment_traffic_filter.default.id]

  elasticsearch {
    topology {
      id   = "hot_content"
      size = "4g"
    }
  }
}
  # google_compute_forwarding_rule.elastic.psc_connection_id
  # To create a traffic filter and adding it to the deployement the elastic forwarding rules should return the PSC Connection ID
  # This is not possible see https://github.com/hashicorp/terraform-provider-google/issues/10588, https://cloud.google.com/compute/docs/reference/rest/v1/forwardingRules
  # Because of this the traffic filter should be created manually and added to the deployment https://www.elastic.co/guide/en/cloud/current/ec-traffic-filtering-psc.html#ec-traffic-filtering-psc
  #resource "ec_deployment_traffic_filter" "default" {
  #  name   = var.project_name
  #  region                 = "gcp-${var.gcp_region}"
  #  type   = "gcp_private_service_connect_endpoint"
  #
  #  rule {
  #    source = "" 
  #  }
  #}
  
resource "google_compute_global_address" "default" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network                 = var.gcp_network
}
  
resource "google_service_networking_connection" "default" {
  network                 = var.gcp_network
  depends_on = [google_project_service.api_services]
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.default.name]
}