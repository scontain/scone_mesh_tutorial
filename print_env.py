import os

# Get some environment variables
API_USER = os.getenv('API_USER')
API_PASSWORD = os.environ.get('API_PASSWORD')

# Print these
print(f"Hello '{API_USER}' - thanks for passing along the API_PASSWORD")

# Exit with error if one is not defined
if API_USER == None or API_PASSWORD == None:
    print("Not all required environment variables are defined!")
    exit(1)
