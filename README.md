# 校园网认证流程分析及自动认证脚本

很久之前在处理Linux终端环境下校园网认证登录时所做的工作，理论上适用于所有基于锐捷网络的认证系统



## 分析过程

未进行校园网认证时`curl -v`任意网站得到

![image-20250311212432818](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220850468-60945062.png)

可见会重定向到认证网址并且附带一些参数

浏览器访问该网址并打开网络日志，输入自己的账号密码测试登录

![image-20250311213009591](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220850932-330329457.png)

找到登录接口，查看负载

![image-20250311213057259](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220851519-1773112898.png)

发现主要包括八个参数，其中需要注意的只有`userId`，`password`、`queryString`和`passwordEncrypt`

仔细观察可以发现`queryString`就是重定向到认证网址时的附带参数

查看发起程序

![image-20250311213500282](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220851925-291624202.png)

分析`AuthInterFace.js`

找到登录相关接口

![image-20250311213650360](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220852320-1121022320.png)

向上在`login_bch.js`中查找`AuthInterFace.login`

定位相关代码行

![image-20250311213822817](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220853280-742322487.png)

分析相关参数是如何得到的

![image-20250311213937402](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220853840-401374770.png)

![image-20250311213952615](https://img2023.cnblogs.com/blog/2433451/202503/2433451-20250311220854575-1849909649.png)

可以看出`queryString`是原始字符串通过两次`url`编码得到，

`userId`也是`username`通过两次`url`编码得到（`Tj_yes`特殊处理，猜测是同济）

`password`似乎会有加密处理，但是考虑到存在`passwordEncrypt`参数，猜测可以通过设置为`true`来避免加密



至此分析完毕。

## 自动登录脚本

`Linux`中使用`curl`可以很便捷的编写自动登录脚本如下，考虑到终端环境注释等也采用英文

```bash
#!/bin/bash

url_encode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    for (( i=0; i<strlen; i++ )); do
        char="${string:i:1}"
        case "$char" in
            [-_.~a-zA-Z0-9] ) encoded+="$char" ;;
            * ) printf -v encoded_char '%%%02x' "'$char"
                encoded+="$encoded_char" ;;
        esac
    done
    echo "$encoded"
}

# Set the username and passwd
USER_ID="your username"
PASSWORD="your password"

echo "Test network connection..."
response=$(curl -s "http://baidu.com")

# Checks whether the network has been authenticated
if echo "$response" | grep -q "http://www.baidu.com/"; then
    echo "Network connected."
    exit 0
fi
# Step 1: get query string
echo "Get query string..."
query_string=$(echo "$response" | grep -oP "top\.self\.location\.href='http://172\.16\.128\.139/eportal/index\.jsp\?\K[^']+")

# test for query string
if [ -z "$query_string" ]; then
    echo "Error: fail to get the query string"
    exit 1
fi

# quote query string twice 
encoded_qs_once=$(url_encode "$query_string")
encoded_qs_twice=$(url_encode "$encoded_qs_once")

# Step 2：constructs the post request parameters
post_data=$(
    cat <<EOF
userId=${USER_ID}&password=${PASSWORD}&service=&queryString=${encoded_qs_twice}&operatorPwd=&operatorUserId=&validcode=&passwordEncrypt=false
EOF
)

# echo "$post_data"

# Step 3：send post request
echo "Trying to login..."
login_response=$(curl -s -X POST "http://172.16.128.139/eportal/InterFace.do?method=login" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.84 Safari/537.36" \
    -H "Referer: http://172.16.128.139/eportal/index.jsp" \
    -H "Accept: */*" \
    -H "Accept-Encoding: gzip, deflate" \
    -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --data "$post_data")

# Step 4：Check the response
if echo "$login_response" | grep -q '"result":"success"'; then
    echo "Login successfully."
else
    echo "Login failure. Error:"
    echo "$login_response" | sed 's/.*"message":"\([^"]*\).*/\1/'
fi
```

对于`Windows`采用`powershell`脚本如下

```powershell
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
```

<mark>需要注意需要更改其中认证链接为自己校园网认证链接</mark>



## Windows计划任务

我们希望连接校园网时能够自动无感认证，自然想到Windows计划任务

查阅资料后，发现可以参考[如何设置计划任务或者脚本才能使电脑在连接指定wifi后自动运行某程序？ - 知乎](https://www.zhihu.com/question/50249683)

其中操作选项卡处如下填写

- 操作：`启动程序`
- 程序/脚本：`powershell`
- 参数：`-ExecutionPolicy Bypass -File "C:\Path\To\YourScript.ps1"`



完整脚本可见[此处](https://github.com/snape-max/campusnet_login)



