# Deploy F5 BIG-IP Virtual Edition in AWS

Terraform template to deploy F5 BIG-IP Virtual Edition in AWS, per [AskF5 docs](https://support.f5.com/kb/en-us/products/big-ip_ltm/manuals/product/bigip-ve-setup-amazon-ec2-11-4-0/2.html)

Change or override whatever variables you see fit in variables.tf and then run
```
terraform apply
```

Note that all non-AWS setup and F5 licensing is manual, after terraform finishes.