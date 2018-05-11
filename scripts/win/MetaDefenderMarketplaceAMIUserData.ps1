<powershell>
$lock = "C:\Program Files\OPSWAT\pwd_ch_lock"
$restUrl = "http://localhost:8008"

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

    $loginUrl = $restUrl + "/login"
    $response = Invoke-WebRequest -UseBasicParsing -Uri $loginUrl -Method POST -Body $body -ContentType "application/json" | ConvertFrom-Json    
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
    
    $changePassUrl = $restUrl + "/user/changepassword"

    #Change password
    return Invoke-WebRequest -UseBasicParsing -Uri $changePassUrl -Method POST -Headers $headers -Body $body -ContentType "application/json" | 
            ConvertFrom-Json    
}

function AWSGetInstanceId() {
    #Get instance name
    return Invoke-WebRequest -UseBasicParsing -Uri http://169.254.169.254/latest/meta-data/instance-id -Method GET         
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
}
Catch
{
    HandleException -exception $_.Exception 
}
</powershell>
<persist>true</persist>