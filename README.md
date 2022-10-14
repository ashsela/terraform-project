# Terraform-Project

In this project I have created an infrastructure for the Weight Tracker application using Microsoft Azure and Terraform.

## To deploy the enviroment follow these steps in the terminal:

1 . To initialize Terraform working directory run

```bash
terraform init
```

2 . To deploy the enviroment:

2.1. If you are using .tfvars file run:

```bash
terraform apply -var-file="FILE_NAME.tfvars"
```

2.2. If you want to enter values interactively just run terraform apply

```bash
Note: add optional flag "-auto-approve" to automatically approve the plan.
```
for example:

```bash
terraform apply -var-file="FILE_NAME.tfvars" -auto-approve
```

To remove whole enviroment run:

```bash
terraform destroy
```

If you are used .tfvars file run:

```bash
terraform destroy -var-file="FILE_NAME.tfvars" 
```

