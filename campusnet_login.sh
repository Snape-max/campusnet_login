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
