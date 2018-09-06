<powershell>

# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},
# {"Fn::Join": ["", ["$MDCentralMgmtIP = ", "\"", {"Fn::GetAtt": ["MDCentralMgmtWindowsEC2AZ1", "PublicIp"] }, "\""]]},
# {"Fn::Join": ["", ["$MDCentralMgmtId = ", "\"", {"Ref": "MDCentralMgmtWindowsEC2AZ1"}, "\""]]},
# {"Fn::Join": ["", ["$DefaultPass = ", "\"", {"Ref": "ElasticLoadBalancer"}, "\""]]},

$coreRestPort = "8008"
$cmRestPort = "8018"

Try
{
    $instance = AWSGetInstanceId  
    $instanceIP = "localhost"
        
    $mdCoreSessionId = MetaDefenderInitialSetup -restPort $coreRestPort -newPass "$DefaultPass" -lambdaFunction "$LambdaFnName"
       
    # activate MetaDefender Core instances
    MetaDefenderActivateLicense -apikey $mdCoreSessionId -restIP $instanceIP -restPort $coreRestPort -instanceId "$instance"
    
    # attach the MetaDefender instance to Central Management 
    MetaDefenderCMAddInstance -instanceIP "$instanceIP" -instancePass "$DefaultPass" -instanceId "$instance" -restPort "$coreRestPort"
    
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
