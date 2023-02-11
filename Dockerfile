# Use an Alpine Linux image as the base image
FROM alpine:3.12

# Install curl and jq
RUN apk add --no-cache curl jq

# Copy the script to the image
COPY script.sh /script.sh

# Make the script executable
RUN chmod +x /script.sh

# Set the default command to run the script
CMD ["/script.sh"]
