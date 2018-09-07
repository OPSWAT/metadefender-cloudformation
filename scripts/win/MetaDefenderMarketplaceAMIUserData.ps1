$restIP = "localhost"
$restPort = 8008
$restUrl = "http://" + $restIP + ":" + $restPort
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
    Invoke-WebRequest -UseBasicParsing -Uri $createUserUrl -Method POST -Body $body -Headers $headers -ContentType "application/json" | ConvertFrom-Json
}


#check if MetaDefender service is up
while (-not (Test-NetConnection localhost -Port 8008 | ? { $_.TcpTestSucceeded } )) {
    #retry every 3 seconds
    sleep 3
}

Try
{
    $indexHTML = $restURL + "/index.html"
    $wizardHTML = Invoke-WebRequest -UseBasicParsing -Uri $indexHTML -Method GET
    $found = $wizardHTML.content -match "wizard\..*\.js"   
    if (-not $found){
        return $false
    }    
    
    $wizardJSURL = $restURL + "/assets/js/" + $matches[0]
    echo "Wizard Location: $wizardJSURL"
    $wizardJ = Invoke-WebRequest -UseBasicParsing -Uri $wizardJSURL -Method GET 
    $found = $wizardJ -match 'setSessionId\("[a-zA-Z0-9]+'
    if (-not $found) {
        return $false
    }
    $defaultAPIKey = $matches[0] -replace 'setSessionId\("', ""    
    $instance = AWSGetInstanceId
    # $instance = "admin"
    
    MetaDefenderCreateUser -username "admin" -password "$instance" -apikey "$defaultAPIKey"
    
    $headers = @{
        "apikey"="$defaultAPIKey";
    }

    $welcomeURL = $restURL + "/admin/welcome"    
    Invoke-WebRequest -UseBasicParsing -Uri $welcomeURL -Method POST -Headers $headers
}
Catch
{
    # HandleException -exception $_.Exception 
    $exception = $_.Exception
    $resp = $exception.Response

    if ($resp -eq $null)
    {
        Write-host $_.Exception
    }
    else
    {
        $responseStream = $resp.GetResponseStream()
        $streamReader = new-object System.IO.StreamReader $responseStream
        $errorStackTrace = $streamReader.ReadToEnd() 
        $errorMessage = [string]$Exception.Message
        $statusCode = $Exception.Response.StatusCode.Value__
        $errorMessage = "Failed :`nReason: [$statusCode] $errorMessage`n$errorStackTrace" 
        Write-Error -message $errorMessage -exception $exception 
    }
}
