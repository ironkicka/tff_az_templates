# How to use

- Deploy
```shell
terraform plan
terraform apply
```

- Destroy all resources
```shell
terraform destroy
```

- Destroy only vm and its related resources
```shell
terraform destroy -target=azurerm_linux_virtual_machine.myterraformv
```

- Get your private key
```shell
terraform output -raw tls_private_key > secret_key.pem 
```

- Connect to VM
```shell
ssh -i path/to/secret_key.pem azureuser@VM_PUBLIC_IP
```