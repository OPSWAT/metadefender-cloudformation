
# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},
# {"Fn::Join": ["", ["$MDCentralMgmtIP = ", "\"", {"Fn::GetAtt": ["MDCentralMgmtWindowsEC2AZ1", "PublicIp"] }, "\""]]},
# {"Fn::Join": ["", ["$MDCentralMgmtId = ", "\"", {"Ref": "MDCentralMgmtWindowsEC2AZ1"}, "\""]]},

$coreRestPort = "8008"
$cmRestPort = "8018"

function GetMetaDefenderRESTURL() {
    Param 
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $InstanceIP,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $RESTPort,
        [Parameter(Mandatory=$false, Position=2)]
        [string] $RESTEndpoint
    )
    
    if (!($RESTEndpoint))
    {
        $RESTEndpoint = ""
    }

    return "http://" + "$InstanceIP" + ":" + "$RESTPort" + "/" + $RESTEndpoint
}
function MetaDefenderCreateUser() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $username,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $password, 
	    [Parameter(Mandatory=$true, Position=2)]
	    [string] $apikey
    )
    $body = @{
	    "directory_id"="1";
        "name"="$username";
	    "display_name"="$username";
	    "email"="$username@local.com";
	    "roles"=@("1");
        "password"="$password";
    } | ConvertTo-Json

    $headers = @{
	    "apikey"="$apikey";
    } 

    $createUserUrl = $restUrl + "/admin/user"
    echo "API Call: $loginURL with body $body "
    Invoke-WebRequest -UseBasicParsing -Uri $createUserUrl -Method POST -Body $body -Headers $headers -ContentType "application/json" | ConvertFrom-Json
}
function MetaDefenderDeleteUser() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $username,
	    [Parameter(Mandatory=$true, Position=1)]
        [string] $apikey
    )
    $body = @{
        "name"="$username";
    } | ConvertTo-Json
    
    $headers = @{
        "apikey"="$apikey";
    }

    $deleteUserUrl = $restUrl + "/admin/user/1"
    echo "API Call: $loginURL with body $body"
    Invoke-WebRequest -UseBasicParsing -Uri $deleteUserUrl -Method DELETE -Body $body -Headers $headers -ContentType "application/json" | ConvertFrom-Json
}
function MetaDefenderLogin() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $username,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $password,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $restIP,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $restPort
    )

    $body = @{
        "user"="$username";
        "password"="$password";
    } | ConvertTo-Json
    
    $loginUrl = GetMetaDefenderRESTURL -InstanceIP $restIP -RESTPort $restPort -RESTEndpoint "login"    
    $response = Invoke-WebRequest -UseBasicParsing -Uri $loginUrl -Method POST -Body $body -ContentType "application/json" | ConvertFrom-Json    
    
    # return the sessionId -> will be used as apikey
    return $response.session_id    
}

function MetaDefenderChangePassword() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $restIP,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $restPort,
 	    [Parameter(Mandatory=$false, Position=3)]
        [string] $password         
    )

    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }

    if (!($password)) {
	    $password = $instance
    } 
    
    #Create new password body
    $body = @{
        "old_password"="admin";
        "new_password"="$password";
    } | ConvertTo-Json
    
    $changePassUrl = GetMetaDefenderRESTURL -InstanceIP $restIP -RESTPort $restPort -RESTEndpoint "user/changepassword"
    
    # Change password
    $response = Invoke-WebRequest -UseBasicParsing -Uri $changePassUrl -Method POST -Headers $headers -Body $body -ContentType "application/json" | 
            ConvertFrom-Json    
    
    return $response
}

function MetaDefenderActivateLicense () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $restIP,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $restPort,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $instanceId,    
        [Parameter(Mandatory=$false, Position=4)]
        [int] $quantity    
    )
    $Comment = "MetaDefender AWS Instance: $instanceId"
    
    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }
    
    if (!($quantity))
    {
        $quantity = 1
    }
    
    $body = @{
        "activationKey" = "$ActivationKey"; 
        "quantity" = "$quantity"; 
        "comment" = "$Comment";
    } | ConvertTo-Json
    
    $activationUrl = GetMetaDefenderRESTURL -InstanceIP $restIP -RESTPort $restPort -RESTEndpoint "admin/license/activation"
    return Invoke-WebRequest -UseBasicParsing $activationUrl -Headers $headers -ContentType "application/json" -Method POST -Body $body 
}
function MetaDefenderLicenseDetails () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $restIP,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $restPort         
    )
    
    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }
        
    $licenseUrl = GetMetaDefenderRESTURL -InstanceIP $restIP -RESTPort $restPort -RESTEndpoint "admin/license"
    $ActivationDetails = Invoke-WebRequest -UseBasicParsing $licenseUrl -Headers $headers -ContentType "application/json" -Method GET    
    return $ActivationDetails
}
function MetaDefenderCMCreateGroup() {
    Param 
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey
    )
    $headers = @{
        "apikey"="$apikey";
    }

    $body = @{
        "name" = "MDCoreAWS";        
        "description" = "Distributed MetaDefender Core intances";        
    } | ConvertTo-Json
    
    $createGroupURL = GetMetaDefenderRESTURL -InstanceIP "localhost" -RESTPort $cmRestPort -RESTEndpoint "admin/group"
    

    Invoke-WebRequest -UseBasicParsing $createGroupURL -Headers $headers -Body $body -ContentType "application/json" -Method POST        
}
function MetaDefenderCMAddInstance () {
    Param
    (
        [Parameter(Mandatory=$true, Position=1)]
        [string] $instanceIP,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $instancePass,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $restPort,
        [Parameter(Mandatory=$true, Position=4)]
        [string] $instanceId         
    )  
    try 
    {        
        #Set session id as apikey header
        
        $instanceIP = AWSGetInstanceIP
        $address = GetMetaDefenderRESTURL -InstanceIP $instanceIP -RESTPort $coreRestPort
        $description = "MetaDefender Core - $instanceId"

        $apikey = MetaDefenderLogin -username "admin" -password "$MDCentralMgmtId" -restIP $MDCentralMgmtIP -restPort $cmRestPort
        $headers = @{
            "apikey"="$apikey";
        }

        $body = @{
            "user" = "admin";
            "password" = "$instancePass";
            "apikey" = "";
            "tags" = @();
            "description" = "$description";
            "name" = "$instanceId";
            "address" = "$address";
            "import" = $true;
        } | ConvertTo-Json
        
        $addInstanceUrl = GetMetaDefenderRESTURL -InstanceIP "$MDCentralMgmtIP" -RESTPort $cmRestPort -RESTEndpoint "admin/group/1/addinstance"
        Invoke-WebRequest -UseBasicParsing $addInstanceUrl -Headers $headers -Body $body -ContentType "application/json" -Method POST    
    }
    catch 
    {
        Write-host $_.Exception 
    }       
        
}

function MetaDefenderInitialSetup() {
    Param 
    {
        [Parameter(Mandatory=$true, Position=0)]
        [string] $restPort,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $newPass,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $lambdaFunction
        [Parameter(Mandatory=$false)]
        [string] $instanceIP='localhost'

    }
    
    #check if MetaDefender service is up
    while (-not (Test-NetConnection localhost -Port $coreRestPort | ? { $_.TcpTestSucceeded } )) {
        # wait for MetaDefender service to start
        # retry every 3 seconds
        sleep 3
    }

    Try
    {
        $instance = AWSGetInstanceId  
        
        # login with default credentials
        $mdSessionId = MetaDefenderLogin -username "admin" -password "admin" -restIP $instanceIP -restPort $restPort
        
        # change the password to instance-id from admin/admin
        MetaDefenderChangePassword  -apikey $mdSessionId -restIP $instanceIP -restPort $restPort -password $newPass    
        
        # update the lambda variables with the new MetaDefender Core instance details 
        #  - save intanceId and deploymentId as envVariable
        AWSUpdateLambdaVariables -FunctionName $lambdaFunction -SessionID $mdSessionId -InstanceID $instance -CoreRESTPort $restPort -CoreIP $instanceIP    
        
        # update the CloudWatch EventRule
        #  - add the instanceId to the eventPattern
        AWSUpdateCWEventRule  

        return $mdSessionId
    }
    Catch
    {
        HandleException -exception $_.Exception 
    } 
 }
function AWSGetInstanceId() {
    #Get instance name
    return Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id -Method GET         
}

function AWSGetInstanceIP() {
    #Get instance name
    return Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/local-ipv4 -Method GET         
}

function AWSUpdateLambdaVariables() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $FunctionName,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $SessionID,
        [Parameter(Mandatory=$true, Position=2)]
        [String] $InstanceID, 
        [Parameter(Mandatory=$true, Position=3)]
        [String] $CoreIP, 
        [Parameter(Mandatory=$true, Position=4)]
        [String] $CoreRESTPort 
    )

    $ActivationDetails = MetaDefenderLicenseDetails -apikey $SessionID -restIP $CoreIP -restPort $CoreRESTPort | ConvertFrom-Json
    
    $deploymentID = $ActivationDetails.deployment
    $envVarInstanceId = "$InstanceID".replace('-', '_')

    $environmentVariables = @{
        "$envVarInstanceId" = "$deploymentID";        
    }  

    $configuration = Get-LMFunctionConfiguration -FunctionName $FunctionName
    $existingVars = $configuration.Environment.Variables
    
    $jsonVars = $existingVars | ConvertTo-Json    

    $keys = $existingVars.getenumerator() | foreach-object {$_.key}
    $keys | foreach-object {
        $key = $_
        if ($environmentVariables.containskey($key))
        {
            $existingVars.remove($key)
        }
    }

    $allVars = $existingVars + $environmentVariables   
    
    $jsonVars = $allVars | ConvertTo-Json    
    
    Update-LMFunctionConfiguration -FunctionName $FunctionName -Environment_Variable $allVars
}

function AWSUpdateCWEventRule() {    
    
    #update event rule to limit lambda function to this instance
    $eventRule = Get-CWERule -NamePrefix $CWEventRule
    $pattern = $eventRule.EventPattern | ConvertFrom-Json
    $ruleDetails = $pattern.detail
    
    $instanceIds = @($instance)
    if ($ruleDetails | Get-Member -Name 'instance-id') {
        $existingIds = $ruleDetails | Get-Member -Name 'instance-id'
	$instanceIds = $existingIds + $instance
    }   
    
    $ruleDetails | Add-Member -Force -Name 'instance-id' -Type NoteProperty -Value $instance
    $new_pattern = $pattern | ConvertTo-Json

    # update the rule
    Write-CWERule -Name $CWEventRule -EventPattern $new_pattern
}

function HandleException() {
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [System.Exception] $exception   
    )

    $resp = $exception.Response

    if ($resp -eq $null)
    {
        Write-host $exception
    }
    else
    {
        $responseStream = $resp.GetResponseStream()
        $streamReader = new-object System.IO.StreamReader $responseStream
        $errorStackTrace = $streamReader.ReadToEnd() 
        $errorMessage = [string]$Exception.Message
        $statusCode = $Exception.Response.StatusCode.Value__
        $errorMessage = "Unable to activate license $ActivationKey :`nReason: [$statusCode] $errorMessage`n$errorStackTrace" 
        Write-Error -message $errorMessage -exception $exception 
    }
}
