terraform {
  required_providers {

    ansible = {
      source = "ansible/ansible"
    }
    proxmox = {
      source  = "telmate/proxmox"
    }
  }
}
