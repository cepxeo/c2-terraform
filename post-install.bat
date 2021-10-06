rem SET AWS_REDIR_IP=1.1.1.1
SET AZURE_REDIR_IP=2.2.2.2
SET AZURE_COBALT_IP=3.3.3.3

rem echo 'Downloading website keystore from AWS redirector.'
rem scp -i aws\kali.pem ubuntu@%AWS_REDIR_IP%:/tmp/example.com.store .

echo 'Downloading website keystore from Azure redirector.'
scp -i azure-redir\redir-key.pem azureuser@%AZURE_REDIR_IP%:/tmp/example.com.store .

echo 'Uploading keystore to Cobalt server.'
scp -i azure-cobalt\cobalt-key.pem example.com.store azureuser@%AZURE_COBALT_IP%:cobaltstrike/domain.store

rem echo 'Locking down HTTPS on Cobalt server.'
rem az network nsg rule update -g pentestRG --nsg-name coba-nsg --name HTTPS --source-address-prefix %AWS_REDIR_IP%

rem echo 'Starting Cobalt ...'
rem ssh -i azure-cobalt\azure.pem azureuser@%AZURE_COBALT_IP% "cd cobaltstrike; sudo ./teamserver 10.0.2.4 %COBALT_PASS% jquery-c2.4.3.profile &"