
### C2 Deployment on AWS / Azure with Terraform

Terraform scripts to create HTTP/S redirectors on AWS and Azure along with Cobalt Strike server on Azure. Besides the resources deployment automates the following:

* Setup the nginx for redirection with custom config to forward CS beacon requests only.
* Generation and registration of SSL certificate via Let's Encrypt and certbot.
* Deploy dummy web site instead of default nginx page
* CS installation delivery to the C2 server and preps required to run the teamserver.

#### Building C2 Server

* Archive your Cobalt Strike folder to cs.tar and copy to `azure-cobalt\configs` folder. 
* Fill in `azure-cobalt\terraform.tfvars` with Azure secrets.
* Execute the build.

```
cd azure-cobalt; terraform init; terraform apply; cd ..
```

Once the build is completed and outputs printed, save the private key to access the server over SSH.
Note the public IP of the server.

#### Building HTTP/S redirect server on Azure / AWS

* Ensure you have a domain name registered.
* Open the DNS Management for your domain and be ready to change the `A Record` to the IP generated during the following build process.
* For Azure, fill in `azure-redir\terraform.tfvars` with your domain name, Public IP of previously created C2 server and Azure secrets. Change `AAA` in arm_subnet_id to your subscription ID.
* For AWS fill in `aws\terraform.tfvars` with your domain name, Public IP of previously created C2 server and AWS secrets.
* Execute the build.

```
cd azure-redir; terraform init; terraform apply
cd aws; terraform init; terraform apply
```

Important!!! Follow the server creation process. Once the public IP is printed to the screen, update the DNS `A Record` in your domain DNS Management immediately. It will be used on the last build stage by the certbot during the SSL certificate registration.

Once the build is completed and outputs printed, save the SSH private key and public IP to access the server later.

#### Destroying C2

Ensure you follow the next order:

```
cd azure-redir; terraform destroy -auto-approve; cd ..
cd azure-cobalt; terraform destroy -auto-approve; cd ..
cd aws; terraform destroy -auto-approve; cd ..
```

#### Post deployment (optional)

Check post-install.bat which locks down the 443 ports on C2 Server to accept connections from redirect server only and uploads the redirect server SSL keystore to C2 server.