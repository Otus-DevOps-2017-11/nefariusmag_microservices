output "endpoint_ip" {
  value = "${google_container_cluster.primary.endpoint}"
}

output "use_it_for_config_kubectl" {
  value = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project}"
}
