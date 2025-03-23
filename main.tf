# main.tf - Main resource definitions

# Create a VM instance
resource "google_compute_instance" "ubuntu_server" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-noble-amd64-v20250313"
      size  = var.disk_size
      type  = "pd-balanced"
    }
  }

  # Enable SSH
  metadata = {
    ssh-keys = "${var.ssh_username}:${file(var.ssh_pub_key_path)}"
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }

  # Tags for firewall rules
  tags = var.network_tags
  # Upload and execute the Kubernetes setup script
  provisioner "file" {
    source      = "kubeadm_crio.sh"
    destination = "/tmp/kubeadm_crio.sh"

    connection {
      type        = "ssh"
      user        = var.ssh_username
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/kubeadm_crio.sh",
      "sudo /tmp/kubeadm_crio.sh"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_username
      private_key = file(var.ssh_private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }
}

# Create a firewall rule to allow SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "6443", "10250", "10251", "10252", "2379", "2380"]
  }

  source_ranges = var.source_ranges
  target_tags   = ["ssh"]
}

# Create a firewall rule to allow all traffic (use with caution)
resource "google_compute_firewall" "allow_all" {
  name    = "allow-all-traffic"
  network = "default"

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["all-traffic"]
}