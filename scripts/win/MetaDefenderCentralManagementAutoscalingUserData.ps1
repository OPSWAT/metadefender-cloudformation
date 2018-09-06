<powershell>

# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},
# {"Fn::Join": ["", ["$MaxMetaDefender = ", "\"", {"Ref": "MaxMetaDefender"}, "\""]]},

$cmRestPort = "8018"


Try
{  
    $instance = AWSGetInstanceId    
    $sessionId = MetaDefenderInitialSetup -restPort $cmRestPort -newPass "$instance" -lambdaFunction "$LambdaFnName"
    
    # activate the license key
    MetaDefenderActivateLicense -apikey "$sessionId" -restIP "localhost" -restPort "$cmRestPort" -instanceId "$instance" -quantity $MaxMetaDefender
    
    # create the group
    MetaDefenderCMCreateGroup -apikey "$sessionId"        
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
<persist>true</persist>
