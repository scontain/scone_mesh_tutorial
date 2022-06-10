import os
import time

# Get some environment variables.
API_USER = os.environ.get('API_USER', None)
API_PASSWORD = os.environ.get('API_PASSWORD', None)

# Exit with error if either one is not defined in service.yml.
if API_USER is None or API_PASSWORD is None:
    print("Not all required environment variables are defined!")
    exit(1)

# We may print API_USER, since it, unlike the API_PASSWORD, is not confidential.
print(f"Hello '{API_USER}' - thanks for passing along the API_PASSWORD", flush=True)

while True:
  print("Stop me by executing 'helm uninstall pythonapp'", flush=True)
  time.sleep(10)
