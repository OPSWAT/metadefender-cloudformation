<powershell>

# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},
$restUrl = "http://localhost:8008"

Try
{
    $instance = AWSGetInstanceId  
    $instanceIP = "localhost"
        
    $mdCoreSessionId = MetaDefenderInitialSetup -restPort $coreRestPort -newPass "$DefaultPass" -lambdaFunction "$LambdaFnName"
       
    # activate MetaDefender Core instances
    MetaDefenderActivateLicense -apikey $mdCoreSessionId -restIP $instanceIP -restPort $coreRestPort -instanceId "$instance"    
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
<persist>true</persist>
