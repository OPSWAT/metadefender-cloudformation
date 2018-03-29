<powershell>
$lock = "C:\Program Files\OPSWAT\pwd_ch_lock"
# {"Fn::Join": ["", ["$ActivationKey = ", "\"", {"Ref": "ActivationKey"}, "\""]]},
# {"Fn::Join": ["", ["$LambdaFnName = ", "\"", {"Ref": "DeactivateLambda"}, "\""]]},


function MetaDefenderLogin() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $username,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $password
    )
    $body = @{
        "user"="$username";
        "password"="$password";
    } | ConvertTo-Json

    $response = Invoke-WebRequest -UseBasicParsing -Uri http://localhost:8008/login -Method POST -Body $body -ContentType "application/json" | ConvertFrom-Json    
    return $response.session_id    
}

function MetaDefenderChangePassword() {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey         
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
    
    #Change password
    return Invoke-WebRequest -UseBasicParsing -Uri http://localhost:8008/user/changepassword -Method POST -Headers $headers -Body $body -ContentType "application/json" | 
            ConvertFrom-Json    
}

function MetaDefenderActivateLicense () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey         
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
    return Invoke-WebRequest -UseBasicParsing http://localhost:8008/admin/license/activation -Headers $headers -ContentType "application/json" -Method POST -Body $body 
}

function MetaDefenderLicenseDetails () {
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $apikey         
    )
    
    #Set session id as apikey header
    $headers = @{
        "apikey"="$apikey";
    }
    
    $ActivationDetails = Invoke-WebRequest -UseBasicParsing http://localhost:8008/admin/license -Headers $headers -ContentType "application/json" -Method GET    
    return $ActivationDetails
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
    $instanceFilter = 
    
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
    $sessionId = MetaDefenderLogin -username $credentials.user -password $credentials.password

    if ($shouldChangePassword) {
        $response = MetaDefenderChangePassword  -apikey $sessionId
        if ($response) {
            #Create passwd change lock
            New-Item "$lock" -ItemType file
        }
    }
    
    MetaDefenderActivateLicense -apikey $sessionId
    $ActivationDetails = MetaDefenderLicenseDetails -apikey $sessionId | ConvertFrom-Json

    # $S3AccessCredentials = AWSS3Credentials
    $deploymentID = $ActivationDetails.deployment

    $environmentVariables = @{
        "DeploymentID" = "$deploymentID";
        "ActivationKey" = "$ActivationKey";
    }    

    AWSUpdateLambdaVariables -FunctionName $LambdaFnName -EnvironmentVariables $environmentVariables -InstanceID $instance
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
<persist>true</persist>