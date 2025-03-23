# outputs.tf - Output definitions

output "instance_name" {
  value       = google_compute_instance.ubuntu_server.name
  description = "Name of the instance"
}

output "instance_zone" {
  value       = google_compute_instance.ubuntu_server.zone
  description = "Zone of the instance"
}

output "instance_machine_type" {
  value       = google_compute_instance.ubuntu_server.machine_type
  description = "Machine type of the instance"
}

output "instance_external_ip" {
  value       = google_compute_instance.ubuntu_server.network_interface[0].access_config[0].nat_ip
  description = "External IP address of the instance"
}

output "ssh_command" {
  value       = "ssh ${var.ssh_username}@${google_compute_instance.ubuntu_server.network_interface[0].access_config[0].nat_ip}"
  description = "SSH command to connect to the instance"
}