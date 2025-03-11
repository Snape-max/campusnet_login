# Set the username , password and network ssid
$USER_ID = "your username"
$PASSWORD = "your password"
$SSID = "your campus wifi name"



$wifiOutput = (netsh wlan show interfaces) -match "^\s*SSID\s+:"
$ssidMatch = $wifiOutput | Select-String -Pattern ':\s*(.+)'
$ssid = $ssidMatch.Matches.Groups[1].Value.Trim()

if ($ssid -ne $SSID) {
    echo "Not connected to the campus network."
    exit 0
}

# Define the URL encoding function
function UrlEncode([string]$str) {
    return [System.Web.HttpUtility]::UrlEncode($str)
}


Write-Host "Testing network connection..."
# Disable automatic redirection to get the original response
$request = [System.Net.WebRequest]::Create("http://baidu.com")
$request.AllowAutoRedirect = $false
try {
    $response = $request.GetResponse()
    $stream = $response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $content = $reader.ReadToEnd()
    $response.Close()
    $reader.Close()
} catch {
    Write-Error "Network request failed."
    exit 1
}

# Check for authentication
if ($content -match "http://www.baidu.com/") {
    Write-Host "Network connected."
    exit 0
}

# Extract query string
Write-Host "Extracting query string..."
if ($content -match "top\.self\.location\.href='http://172\.16\.128\.139/eportal/index\.jsp\?([^']+)") {
    $query_string = $matches[1]
} else {
    Write-Error "Failed to get query string"
    exit 1
}

# URL encoding twice
$encoded_qs_once = [System.Web.HttpUtility]::UrlEncode($query_string)
$encoded_qs_twice = [System.Web.HttpUtility]::UrlEncode($encoded_qs_once)

# Build POST data
$post_data = @"
userId=$USER_ID&password=$PASSWORD&service=&queryString=$encoded_qs_twice&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false
"@

# Send login request
Write-Host "Attempting login..."
$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.84 Safari/537.36"
    "Referer" = "http://172.16.128.139/eportal/index.jsp"
    "Accept" = "*/*"
    "Accept-Encoding" = "gzip, deflate"
    "Accept-Language" = "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6"
    "Content-Type" = "application/x-www-form-urlencoded; charset=UTF-8"
}

try {
    $login_response = Invoke-WebRequest -Uri "http://172.16.128.139/eportal/InterFace.do?method=login" -Method Post -Body $post_data -Headers $headers -UseBasicParsing
} catch {
    Write-Error "Login request failed."
    exit 1
}

# check response
$response_json = $login_response.Content | ConvertFrom-Json
if ($response_json.result -eq "success") {
    Write-Host "Login successful."
} else {
    Write-Host "Login failed. Error: $($response_json.message)"
}