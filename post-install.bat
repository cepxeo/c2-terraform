SET AWS_REDIR_IP="1.1.1.1"
SET AZURE_COBALT_IP="1.1.1.1"

echo 'Locking down HTTPS on CS server.'
az network nsg rule update -g pentestRG --nsg-name coba-nsg --name HTTPS --source-address-prefix %AWS_REDIR_IP%

echo 'Downloading keystore from AWS redirector.'
scp -i aws\aws_redir_key.pem ubuntu@%AWS_REDIR_IP%:/tmp/site.com.store .

echo 'Uploading keystore to CS server.'
scp -i azure-cobalt\azure_cobalt_key.pem site.com.store azureuser@%AZURE_COBALT_IP%:cobaltstrike/domain.store