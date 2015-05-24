# Description:
#   Retrieve Reviewboard information - v2 (HTML Rich)
#
# Dependencies:
#   https,http,fs
#
# Configuration:
#   HUBOT_HIPCHAT_API_V2_AUTH_TOKEN
#
# Commands:
#   !rb reviewId - displays information about review board entry
#
# Author:
#   rjanardhana, inikolaev

# regexp for listening to rb pattern
regexp = /!(rb)\s+([0-9]+)/i

# required for https calls
https = require 'https'

# required for http calls
http = require 'http'

# required to load xmpp_jid,api_id file mapping
fs = require 'fs'

# csv parser
parse = require 'csv-parse'

# Handlerbars templating engine
Handlebars = require 'handlebars'

# Load XMPP JID to API ID Map
xmpp_to_api_map = {}
XMPP_JID_TO_API_ID_FILENAME = "xmpp_jid_to_api_id_map.csv"
rawCSVData = fs.readFileSync(XMPP_JID_TO_API_ID_FILENAME).toString()
parse(rawCSVData, {columns: true}, (err, data) ->
    for item in data
        xmpp_to_api_map[item['xmpp_jid']] = item['api_id']
)

rbHTMLTemplateString = '''
<img style="display: block; margin-right: 2px;" width="16" height="16" src="https://IMAGE_HOSTING_SITE/img/emoticons/rbicon.png"></img>
<a href={{RBUrl}}><b>{{summary}}</b></a> by <b>{{submitter}}</b></br>

<span>   <b>Ship Its: </b>{{shipItCount}}</span>
<span> · <b>Open Issues: </b>{{openIssues}}</span>
<span> · <b>Resolved: </b>{{resolvedIssues}}</span>
<span> · <b>Dropped: </b>{{droppedIssues}}</span></br>
'''

rbTemplate = Handlebars.compile(rbHTMLTemplateString)

# Listen to regexp and respond
module.exports = (robot) ->
    robot.hear regexp, (msg) ->
        # Grab xmpp jid and api room id if it exists
        xmpp_jid = msg.message.user.reply_to
        api_room_id = xmpp_to_api_map[xmpp_jid]

        # Review Id
        reviewId = msg.match[2]

        # Returns an object consisting of json object and raw string
        rbResp = getReviewboardResponse reviewId
        if api_room_id?
            sendHipChatNotification msg, rbResp["json"], api_room_id
        else
            msg.send rbResp["raw_string"]

# getReviewboardResponse
getReviewboardResponse = (reviewId) ->
    json_obj = 
        RBURL: "http://someurl.com"
        summary: "test rb"
        submitter: "ravikiranj"
        shipItCount: 1
        openIssues: 1
        resolvedIssues: 1
        droppedIssues: 0

    return {"json": json_obj, "raw_string": prettifyObj(json_obj)}

# sendHipChatNotification
sendHipChatNotification = (msg, rb, api_room_id) ->
    req_path = "/v2/room/" + api_room_id + "/notification?auth_token=" + process.env.HUBOT_HIPCHAT_API_V2_AUTH_TOKEN # YOUR_AUTH_TOKEN
    post_data = getNotificationPayload rb
    reqOptions =
        host: process.env.HUBOT_HIPCHAT_HOST # YOUR_HIPCHAT_HOST (e.g: hipchat.myhipchatinstance.com)
        port: 443
        path: req_path
        method: "POST"
        headers:
            "Content-Type": "application/json"

     # Construct request object and set listeners
     req = https.request reqOptions, (res) ->
         if res.statusCode != 204 # HTTP Status Code 204 = No Content
             errorHandler msg, res, post_data
             return
         data = ""
         res.on "data", (chunk) ->
             data += chunk.toString()
             return
         res.on "end", () ->
             return
         return
     req.on "error", (e) ->
         errorHandler msg, res, post_data, e
         return

     # Create and send notification
     req.write post_data
     req.end()
     console.log "Sending HipChat notification, payload = ", JSON.stringify(rb)
     return

# getNotificationPayload
getNotificationPayload = (rb) ->
    payload =
        message: rbTemplate(rb)
        message_format: "html"
        color: "yellow"
    return JSON.stringify payload

# errorHandler
errorHandler = (msg, res, post_data, error) ->
    msg.send "Failed to post notification to hipchat server, bug Ravi!"
    if res and res.statusCode
        console.log "Failed to post notification, Status code = #{res.statusCode}"
    if post_data
        console.log "Post Data = #{post_data}"
    if error
        console.log "Error = #{error}"

# Prettify Object
prettifyObj = (obj) ->
    op = ""
    for key, value of obj 
        capKey = capitalizeFirstLetter key 
        op += "#{capKey}: #{value}\n"
    return op

# Capitalize first letter of a word
capitalizeFirstLetter = (word) ->
    if word?
        return word.charAt(0).toUpperCase() + word.slice(1)
    return ""
