<powershell>

# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},
# {"Fn::Join": ["", ["$MDCore1Id = ", "\"", {"Ref": "MDWindowsEC2AZ1"}, "\""]]},
# {"Fn::Join": ["", ["$MDCore1IP = ", "\"", {"Fn::GetAtt": ["MDWindowsEC2AZ1", "PrivateIP"] }, "\""]]},
# {"Fn::Join": ["", ["$MDCore2Id = ", "\"", {"Ref": "MDWindowsEC2AZ2"}, "\""]]},
# {"Fn::Join": ["", ["$MDCore2IP = ", "\"", {"Fn::GetAtt": ["MDWindowsEC2AZ2", "PrivateIP"] }, "\""]]},
$cmRestPort = "8018"
$coreRestPort = "8008"


Try
{  
    $instance = AWSGetInstanceId           
    $sessionId = MetaDefenderInitialSetup -restPort $cmRestPort -newPass "$instance" -lambdaFunction "$LambdaFnName"
   
    MetaDefenderActivateLicense -apikey "$sessionId" -restIP "localhost" -restPort "$cmRestPort" -instanceId "$instance" -quantity 2

    MetaDefenderCMCreateGroup -apikey "$sessionId"
    
    MetaDefenderCMAddInstance -apikey "$sessionId" -instanceIP "$MDCore1IP" -instancePass "$MDCore1Id" -instanceId "$MDCore1Id" -restPort "$coreRestPort"
    MetaDefenderCMAddInstance -apikey "$sessionId" -instanceIP "$MDCore2IP" -instancePass "$MDCore2Id" -instanceId "$MDCore2Id" -restPort "$coreRestPort"
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
<persist>true</persist>
