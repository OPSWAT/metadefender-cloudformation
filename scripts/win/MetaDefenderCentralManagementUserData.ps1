<powershell>
$lock = "C:\Program Files\OPSWAT\pwd_ch_lock"

# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},
# {"Fn::Join": ["", ["$MDCore1Id = ", "\"", {"Ref": "MDWindowsEC2AZ1"}, "\""]]},
# {"Fn::Join": ["", ["$MDCore1IP = ", "\"", {"Fn::GetAtt": ["MDWindowsEC2AZ1", "PrivateIP"] }, "\""]]},
# {"Fn::Join": ["", ["$MDCore2Id = ", "\"", {"Ref": "MDWindowsEC2AZ2"}, "\""]]},
# {"Fn::Join": ["", ["$MDCore2IP = ", "\"", {"Fn::GetAtt": ["MDWindowsEC2AZ2", "PrivateIP"] }, "\""]]},
$cmRestUrl = "http://localhost:8018"
$coreRestUrl = "http://localhost:8008"

function MetaDefenderLogin() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $username,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $password,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $restUrl
    )
    $body = @{
        "user"="$username";
        "password"="$password";
    } | ConvertTo-Json

    $loginUrl = $restUrl + "/login"
    $response = Invoke-WebRequest -UseBasicParsing -Uri $loginUrl -Method POST -Body $body -ContentType "application/json" | ConvertFrom-Json    
    return $response.session_id    
}

function MetaDefenderChangePassword() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $restUrl         
    )

    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }
        
    #Create new password body
    $body = @{
        "old_password"="admin";
        "new_password"="$instance";
    } | ConvertTo-Json
    
    $changePassUrl = $restUrl + "/user/changepassword"

    #Change password
    return Invoke-WebRequest -UseBasicParsing -Uri $changePassUrl -Method POST -Headers $headers -Body $body -ContentType "application/json" | 
            ConvertFrom-Json    
}

function MetaDefenderActivateLicense () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $restUrl         
    )
    $Comment = "MetaDefender AWS Instance: $instance"
    
    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }
    
    $body = @{
        "activationKey" = "$ActivationKey"; 
        "quantity" = "1"; 
        "comment" = "$Comment";
    } | ConvertTo-Json

    $activationUrl = $restUrl + "/admin/license/activation"
    return Invoke-WebRequest -UseBasicParsing $activationUrl -Headers $headers -ContentType "application/json" -Method POST -Body $body 
}

function MetaDefenderLicenseDetails () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $restUrl         
    )
    
    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }
    
    $licenseUrl = $restUrl + "/admin/license"
    $ActivationDetails = Invoke-WebRequest -UseBasicParsing $licenseUrl -Headers $headers -ContentType "application/json" -Method GET    
    return $ActivationDetails
}
function MetaDefenderCMAddInstance () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $instanceIP,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $instancePass,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $restUrl         
    )         
    
    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }

    $body = @{
        "user" = "admin";
        "password" = "$instancePass";
        "description" = "MetaDefender Core - $instancePass";
        "name" = "$instancePass";
        "address"= "http://$instanceIP:8008/";
    }
    
    $addInstanceUrl = $restUrl + "/admin/group/1/addinstance"
    Invoke-WebRequest -UseBasicParsing $addInstanceUrl -Headers $headers -Body $body -ContentType "application/json" -Method POST        
}
function AWSGetInstanceId() {
    #Get instance name
    return Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id -Method GET         
}

function AWSUpdateLambdaVariables() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $FunctionName, 
        [Parameter(Mandatory=$true, Position=1)]
        [hashtable] $EnvironmentVariables,    
        [Parameter(Mandatory=$true, Position=2)]
        [String] $InstanceID          
    )

    Update-LMFunctionConfiguration -FunctionName $FunctionName -Environment_Variable $EnvironmentVariables

    #update event rule to limit lambda function to this instance
    $eventRule = Get-CWERule -NamePrefix $CWEventRule
    $pattern = $eventRule.EventPattern
    
    $new_pattern = $pattern.replace('{"state"', '{"instance-id": ["' + $InstanceID + '"],"state"')

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

$instance = AWSGetInstanceId

#Test for lock
if (Test-Path $lock) {
    
    $credentials = @{
        "user"="admin";
        "password"="$instance";
    }
    $shouldChangePassword = $false
} else {
    $credentials = @{ "user"="admin"; "password"="admin";}
    $shouldChangePassword = $true
}

#check if MetaDefender service is up
while (-not (Test-NetConnection localhost -Port 8008 | ? { $_.TcpTestSucceeded } )) {
    #retry every 3 seconds
    sleep 3
}

Try
{           
    $sessionId = MetaDefenderLogin -username $credentials.user -password $credentials.password -restUrl $cmRestUrl

    if ($shouldChangePassword) {
        $response = MetaDefenderChangePassword  -apikey $sessionId -restUrl $cmRestUrl
        if ($response) {
            #Create passwd change lock
            New-Item "$lock" -ItemType file
        }
    }
    
    $ActivationDetails = MetaDefenderLicenseDetails -apikey $sessionId -restUrl $cmRestUrl | ConvertFrom-Json
    
    $deploymentID = $ActivationDetails.deployment

    $environmentVariables = @{
        "ActivationKey" = "$ActivationKey";        
        "$instance" = "$deploymentID";        
    }    

    AWSUpdateLambdaVariables -FunctionName $LambdaFnName -EnvironmentVariables $environmentVariables -InstanceID $instance

    MetaDefenderActivateLicense -apikey $sessionId


    MetaDefenderCMAddInstance -apikey $$sessionId -instance1IP $MDCore1IP -instance2Id $MDCore1Id -restUrl $cmRestUrl
    MetaDefenderCMAddInstance -apikey $$sessionId -instance2IP $MDCore2IP -instance2Id $MDCore2Id -restUrl $cmRestUrl
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
<persist>true</persist>