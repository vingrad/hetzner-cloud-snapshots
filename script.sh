#!/bin/bash

# Set environment variables
API_TOKEN=${API_TOKEN:-<your API token>}
WEEKLY_SNAPSHOTS=${WEEKLY_SNAPSHOTS:-4}
MONTHLY_SNAPSHOTS=${MONTHLY_SNAPSHOTS:-3}
YEARLY_SNAPSHOTS=${YEARLY_SNAPSHOTS:-2}
SHUTDOWN_SERVER=${SHUTDOWN_SERVER:-false}


# Get the list of all servers in the account
SERVERS_DATA=$(curl -H "Authorization: Bearer ${API_TOKEN}" "https://api.hetzner.cloud/v1/servers")

# Loop through all servers
for SERVER_DATA in $(echo "${SERVERS_DATA}" | jq -r '.servers[]'); do
    # Get the server ID
    SERVER_ID=$(echo "${SERVER_DATA}" | jq -r '.id')

    # Part 1: Check if the server has the AUTOBACKUP = true label
    SERVER_LABEL=$(echo "${SERVER_DATA}" | jq -r '.labels.AUTOBACKUP')
    if [ "$SERVER_LABEL" != "true" ]; then
        continue
    fi

    # Part 2: Get the value of WEEKLY_SNAPSHOTS, MONTHLY_SNAPSHOTS, and YEARLY_SNAPSHOTS (from the server label, if specified)
    SERVER_WEEKLY_SNAPSHOTS=$(echo "${SERVER_DATA}" | jq -r '.labels."AUTOBACKUP.KEEP-LAST-WEEKLY"')
    SERVER_MONTHLY_SNAPSHOTS=$(echo "${SERVER_DATA}" | jq -r '.labels."AUTOBACKUP.KEEP-LAST-MONTHLY"')
    SERVER_YEARLY_SNAPSHOTS=$(echo "${SERVER_DATA}" | jq -r '.labels."AUTOBACKUP.KEEP-LAST-YEARLY"')
    if [ -n "$SERVER_WEEKLY_SNAPSHOTS" ]; then
        WEEKLY_SNAPSHOTS=$SERVER_WEEKLY_SNAPSHOTS
    fi
    if [ -n "$SERVER_MONTHLY_SNAPSHOTS" ]; then
        MONTHLY_SNAPSHOTS=$SERVER_MONTHLY_SNAPSHOTS
    fi
    if [ -n "$SERVER_YEARLY_SNAPSHOTS" ]; then
        YEARLY_SNAPSHOTS=$SERVER_YEARLY_SNAPSHOTS
    fi

    # Part 3: Get the value of AUTOBACKUP.SHUTDOWN_SERVER from the server label
    SERVER_SHUTDOWN_SERVER=$(echo "${SERVER_DATA}" | jq -r '.labels."AUTOBACKUP.SHUTDOWN_SERVER"')

    # Part 4: Shut down the server if specified
    if [ "$SERVER_SHUTDOWN_SERVER" = "true" ]; then
        curl -H "Authorization: Bearer ${API_TOKEN}" -X POST "https://api.hetzner.cloud/v1/servers/${SERVER_ID}/actions/shutdown"
    fi

    # Part 5: Create a snapshot
    TIMESTAMP=$(date +%s)
    DATE=$(date +%Y-%m-%d)
    TIME=$(date +%H:%M:%S)

    # Determine the type of snapshot to create
    if [ "$DATE" == "$WEEKLY_SNAPSHOT_DATE" ]; then
        SNAPSHOT_NAME="${SERVER_NAME}_${DATE}_${TIME}_weekly"
    elif [ "$DATE" == "$MONTHLY_SNAPSHOT_DATE" ]; then
        SNAPSHOT_NAME="${SERVER_NAME}_${DATE}_${TIME}_monthly"
    else
        SNAPSHOT_NAME="${SERVER_NAME}_${DATE}_${TIME}_yearly"
    fi


done


# Part 6: Delete old snapshots
# Get the list of images for this server
SERVER_IMAGES=$(curl -H "Authorization: Bearer ${API_TOKEN}" "https://api.hetzner.cloud/v1/images?label_selector=server-id=${SERVER_ID}")

# Calculate the number of weekly snapshots to delete
WEEKLY_SNAPSHOTS_TO_DELETE=$(($(echo "${SERVER_IMAGES}" | jq -r '.images[].name' | grep "_weekly" | wc -l) - WEEKLY_SNAPSHOTS))

# Delete the oldest weekly snapshots, if necessary
if [ $WEEKLY_SNAPSHOTS_TO_DELETE -gt 0 ]; then
    for i in $(seq 1 $WEEKLY_SNAPSHOTS_TO_DELETE); do
        # Get the ID of the oldest weekly snapshot
        SNAPSHOT_ID_TO_DELETE=$(echo "${SERVER_IMAGES}" | jq -r '.images[].id' | sort | head -n 1)

        # Delete the snapshot
        curl -H "Authorization: Bearer ${API_TOKEN}" -X DELETE "https://api.hetzner.cloud/v1/images/${SNAPSHOT_ID_TO_DELETE}"
    done
fi

# Calculate the number of monthly snapshots to delete
MONTHLY_SNAPSHOTS_TO_DELETE=$(($(echo "${SERVER_IMAGES}" | jq -r '.images[].name' | grep "_monthly" | wc -l) - MONTHLY_SNAPSHOTS))

# Delete the oldest monthly snapshots, if necessary
if [ $MONTHLY_SNAPSHOTS_TO_DELETE -gt 0 ]; then
    for i in $(seq 1 $MONTHLY_SNAPSHOTS_TO_DELETE); do
        # Get the ID of the oldest monthly snapshot
        SNAPSHOT_ID_TO_DELETE=$(echo "${SERVER_IMAGES}" | jq -r '.images[].id' | sort | head -n 1)

        # Delete the snapshot
        curl -H "Authorization: Bearer ${API_TOKEN}" -X DELETE "https://api.hetzner.cloud/v1/images/${SNAPSHOT_ID_TO_DELETE}"
    done
fi

# Calculate the number of yearly snapshots to delete
YEARLY_SNAPSHOTS_TO_DELETE=$(($(echo "${SERVER_IMAGES}" | jq -r '.images[].name' | grep "_yearly" | wc -l) - YEARLY_SNAPSHOTS))

# Delete the oldest yearly snapshots, if necessary
if [ $YEARLY_SNAPSHOTS_TO_DELETE -gt 0 ]; then
    for i in $(seq 1 $YEARLY_SNAPSHOTS_TO_DELETE); do
        # Get the ID of the oldest yearly snapshot
        SNAPSHOT_ID_TO_DELETE=$(echo "${SERVER_IMAGES}" | jq -r '.images[].id' | sort | head -n 1)
        # Delete the snapshot
        curl -H "Authorization: Bearer ${API_TOKEN}" -X DELETE "https://api.hetzner.cloud/v1/images/${SNAPSHOT_ID_TO_DELETE}"
    done
fi

# Part 7: Start the server
if [ "$SHUTDOWN_SERVER" == "true" ]; then
    curl -H "Authorization: Bearer ${API_TOKEN}" -X POST "https://api.hetzner.cloud/v1/servers/${SERVER_ID}/actions/poweron"
fi
