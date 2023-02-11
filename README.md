# hetzner-cloud-snapshots


docker build -t hetzner-snapshot .

This will create a Docker image that you can run as a Docker container. To run the container, you'll need to set the required environment variables for the script:

docker run -e API_TOKEN=your_api_token -e WEEKLY_SNAPSHOTS=number_of_weekly_snapshots -e MONTHLY_SNAPSHOTS=number_of_monthly_snapshots -e YEARLY_SNAPSHOTS=number_of_yearly_snapshots hetzner-snapshot
