--[[
MIT License

Copyright (c) 2019 yogiverma007

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
-- modified

local httprequestparser = {
    VERSION = "1.0neutron",
}

local statusMessages = {
    [200] = "OK",
    [201] = "Created",
    [400] = "Bad Request",
    [404] = "Not Found",
    [500] = "Internal Server Error"
}

local function isEmpty(s)
    return s == nil or s == '' or s == ""
end

local function splitString(toSplitString, delimiter)
    local result = {};
    for match in (toSplitString .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

local function trimString(toTrimString)
    if not toTrimString then return "" end
    local from = toTrimString:match "^%s*()"
    return from > #toTrimString and "" or toTrimString:match(".*%S", from)
end

local function _privatefindElementFromRequestBody(requestBody, element)
    local s, e = string.find(requestBody:lower(), element:lower())
    if e == nil then
        return nil
    end
    local ls, le = string.find(requestBody:lower(), "\n", e)
    local line = requestBody:sub(s, le or #requestBody)
    local columnPos = string.find(line, ':')
    if columnPos == nil then
        return nil
    end
    local elementValue = trimString(line:sub(columnPos + 1))
    return elementValue
end

local function fetchFirstLineFromRequestPayLoad(requestPayload)
    local _, e = string.find(requestPayload, "\n")
    if e == nil then
        return requestPayload
    end
    return requestPayload:sub(1, e)
end

local function fetchRequestBody(requestBodyBuffer)
    local splitRequestBody = splitString(requestBodyBuffer, "\n")
    local flag = false
    local bodyParts = {}

    for _, v in ipairs(splitRequestBody) do
        if not flag and (v == '\r' or v == '' or isEmpty(trimString(v))) then
            flag = true
        elseif flag then
            table.insert(bodyParts, v)
        end
    end
    return table.concat(bodyParts, "\n")
end

local function urlDecode(str)
    if not str then return nil end
    str = str:gsub("+", " ")
    str = str:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return str
end

function httprequestparser.getContentType(requestBodyBuffer)
    return _privatefindElementFromRequestBody(requestBodyBuffer, "Content%-Type")
end

function httprequestparser.getAccept(requestBodyBuffer)
    return _privatefindElementFromRequestBody(requestBodyBuffer, "Accept")
end

function httprequestparser.getHost(requestBodyBuffer)
    return _privatefindElementFromRequestBody(requestBodyBuffer, "Host")
end

function httprequestparser.getAllHeaders(requestBodyBuffer)
    local splitRequestBody = splitString(requestBodyBuffer, "\n")
    local requestHeaders = {}

    for i = 2, #splitRequestBody do
        local v = splitRequestBody[i]
        if isEmpty(trimString(v)) then
            break
        end
        local s, e = string.find(v, ':')
        if s ~= nil then
            local headerName = v:sub(1, s - 1)
            local headerValue = v:sub(s + 1)
            requestHeaders[trimString(headerName)] = trimString(headerValue)
        end
    end
    return requestHeaders
end

function httprequestparser.getHttpMethod(requestBodyBuffer)
    local line = fetchFirstLineFromRequestPayLoad(requestBodyBuffer)
    if not line then return nil end
    local s = string.find(line, '%s')
    if not s then return nil end
    return trimString(line:sub(1, s))
end

function httprequestparser.getRequestURI(requestBodyBuffer)
    local line = fetchFirstLineFromRequestPayLoad(requestBodyBuffer)
    if not line then return nil end
    local s = string.find(line, '%s')
    if not s then return nil end
    local rest = line:sub(s + 1)
    local e = string.find(rest, '%s')
    if e then
        return trimString(rest:sub(1, e))
    end
    return trimString(rest)
end

function httprequestparser.findElementFromRequestBody(requestBodyBuffer, element)
    return _privatefindElementFromRequestBody(requestBodyBuffer, element)
end

function httprequestparser.isJSONBody(requestBodyBuffer)
    local contentType = httprequestparser.getContentType(requestBodyBuffer)
    return contentType ~= nil and string.find(contentType:lower(), 'json') ~= nil
end

function httprequestparser.getRequestBodyAsString(requestBodyBuffer)
    return fetchRequestBody(requestBodyBuffer)
end

function httprequestparser.handleJsonBody(requestBodyBuffer)
    if not httprequestparser.isJSONBody(requestBodyBuffer) then
        return nil
    end

    local requestBody = fetchRequestBody(requestBodyBuffer)
    if isEmpty(requestBody) then
        return nil
    end

    return json.parse(requestBody)
end

function httprequestparser.getQueryParameters(requestBodyBuffer)
    local uri = httprequestparser.getRequestURI(requestBodyBuffer)
    if not uri then return {} end

    local queryParams = {}
    local queryString = uri:match("%?(.*)")

    if queryString then
        for pair in queryString:gmatch("([^&]+)") do
            local key, value = pair:match("([^=]+)=?(.*)")
            if key then
                key = urlDecode(key)
                value = urlDecode(value)

                local isExplicitArray = key:sub(-2) == "[]"
                local cleanKey = isExplicitArray and key:sub(1, -3) or key

                if isExplicitArray then
                    if not queryParams[cleanKey] or type(queryParams[cleanKey]) ~= "table" then
                        queryParams[cleanKey] = {}
                    end
                    table.insert(queryParams[cleanKey], value)
                else
                    if queryParams[cleanKey] then
                        if type(queryParams[cleanKey]) == "table" then
                            table.insert(queryParams[cleanKey], value)
                        else
                            queryParams[cleanKey] = { queryParams[cleanKey], value }
                        end
                    else
                        queryParams[cleanKey] = value
                    end
                end
            end
        end
    end

    if table.count_pairs(queryParams) > 0 then
        return queryParams
    end
end

function httprequestparser.toJsonString(requestBodyBuffer)
    local uriFull = httprequestparser.getRequestURI(requestBodyBuffer)
    local uriPath = uriFull and uriFull:match("([^?]+)") or uriFull

    local result = {
        method = httprequestparser.getHttpMethod(requestBodyBuffer),
        uri = uriFull,
        path = uriPath,
        query = httprequestparser.getQueryParameters(requestBodyBuffer),
        headers = httprequestparser.getAllHeaders(requestBodyBuffer),
        body = nil
    }

    local rawBody = httprequestparser.getRequestBodyAsString(requestBodyBuffer)
    if not isEmpty(trimString(rawBody)) then
        if httprequestparser.isJSONBody(requestBodyBuffer) then
            result.body = json.parse(rawBody)
        else
            result.body = rawBody
        end
    end

    return result
end

function httprequestparser.buildResponse(status, bodyData, extraHeaders)
    local extraHeaders = extraHeaders or {}
    local statusText = statusMessages[status] or "Unknown"
    local responseLine = string.format("HTTP/1.1 %d %s\r\n", status, statusText)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Connection"] = "close"
    }

    table.merge(headers, extraHeaders)

    local content = ""
    if bodyData then
        if type(bodyData) == "table" then
            content = json.tostring(bodyData)
        else
            content = tostring(bodyData)
        end
    end

    headers["Content-Length"] = #content

    local response = responseLine
    for k, v in pairs(headers) do
        response = response .. string.format("%s: %s\r\n", k, v)
    end

    return response .. "\r\n" .. content
end

return httprequestparser