import os
import time
import hashlib

# Get the environment variables. 
# The value of API_USER is set in the meshfile and therefore 
# visible to the sysadmin of the application owner.
user = os.environ.get('API_USER', None)
# The value of API_PASSWORD is generated by CAS and therefore 
# not visible even to the sysadmin of the application owner.
pw = os.environ.get('API_PASSWORD', None)
# Retrieve some explicitly defined secret:
exclaim = os.environ.get('EXCLAIM', None)
disclaimer = os.environ.get('DISCLAIMER', None)
# Retrieve some secret define in the service file:
xpassword = os.environ.get('XPASSWORD', None)
# Exit with error if either one is not defined in service.yaml.
if user is None or pw is None or exclaim is None or xpassword is None:
    print("Not all required environment variables are defined.")
    exit(1)

release = os.environ.get('RELEASE', None)
# Warn if RELEASE is not set up
if release is None:
    print("..:WRN:Either release has not been defined or it is default: pythonapp. Verify the installation.")
    release = 'pythonapp'
    print(f"..:WRN:'release' is now {release}.")
print(f"..:INF:'release' is {release}.")

# We can print API_USER, since it, unlike the API_PASSWORD, is not 
# meant to be confidential.
print(f"Hello, '{user}' - thanks for passing along the API_PASSWORD and xpassword={xpassword}", 
      flush=True)

# We print a checksum of API_PASSWORD, since we want to see
# if and when it changes. 
pw_checksum = hashlib.md5(pw.encode('utf-8')).hexdigest()
print(f"The checksum of the original API_PASSWORD is '{pw_checksum}'")

while True:
  new_user = os.environ.get('API_USER', None)
  print(f"Hello! {exclaim} user '{new_user}'!", flush=True)
  print(f"Disclaimer!\n{disclaimer}.", flush=True)
  if new_user != user:
     print("Integrity violation:" 
           f"The value of API_USER changed from '{user}' to '{new_user}'!")
     exit(1)

  new_pw = os.environ.get('API_PASSWORD', None)
  new_pw_checksum = None
  if new_pw:
     new_pw_checksum = hashlib.md5(new_pw.encode('utf-8')).hexdigest()
  print(f"The checksum of the current password is '{new_pw_checksum}'", 
        flush=True)
  if new_pw_checksum != pw_checksum:
     print("Integrity violation:" 
           f"The checksum of API_PASSWORD changed from '{pw_checksum}' to '{new_pw_checksum}'!")
     exit(1)

  print(f"Stop ME by executing 'helm uninstall {release}'", flush=True)
  time.sleep(10)

