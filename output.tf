output "linux-vm-password"{
    value = random_password.linux-vm-password.result
    sensitive = true
}