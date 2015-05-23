#!/usr/bin/env python

import requests
import json
import csv
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gen_xmpp_jid_to_api_id_mapping")

# Load HipChat Rooms
with open("rooms.json") as data_file:
    # Load JSON 
    data = json.load(data_file)

    # Output file to write the mapping
    op = open("xmpp_jid_to_api_id_map.csv", "w")
    csv_writer = csv.writer(op, quoting=csv.QUOTE_MINIMAL)
    headers = ["xmpp_jid", "api_id"]
    csv_writer.writerow(headers)

    # Room Info API
    base_url = "https://YOUR_HIPCHAT_URL/v2/room/" # default is "https://api.hipchat.com"
    AUTH_TOKEN = "?auth_token=YOUR_AUTH_TOKEN"

    # Loop through each room
    count = 0
    for item in data["items"]:
        id_str = str(item["id"])
        api_url = base_url + id_str + AUTH_TOKEN
        logging.info("Fetching api data for %s, count = %d",api_url, count)

        r = requests.get(api_url)
        if r.status_code != 200:
            logger.info("Response = %s", r.text)
            logger.info("Error!!! Status code = %d, url = %s, continuing with next entry", r.status_code, api_url)
            continue

        op = r.json()
        if "xmpp_jid" in op:
            # XMPP_JID, API_ID
            row = [op["xmpp_jid"].encode('utf-8'), id_str]
            csv_writer.writerow(row)
            logger.info("Row = %s", row)

        # Rate Limit - 100 requests within 300 seconds (5 min) window
        time.sleep(3.5) 

    # Close output file handle
    op.close()
