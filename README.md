# SCONE MESH EXAMPLE

## Hello World

We start with a simple "Hello World" example, in which we pass a user ID and a password to a simple Python program.

This program could look as follows:

```python
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
```

## Objectives

We want to make sure that the password cannot be leaked: even a system admin on the platform cannot see that password.

## Quick Start

To build the application image, execute

```bash
scone apply -m Appfile.yml
```

To build the application, execute

```bash
scone apply -m meshfile.yml
```

**todo**: explain `helm install`

## Building a Confidential Image

We can build a confidential container image with the help of a manifest of kind `genAppImage`.

Our objective is to build a confidential container image to run this application encrypted and ensure that environment variables are securely passed to the application only after the application was attested and verified.

Note that we want to outsouce the management of Kubernetes to an external provider. Hence, we do not want Kubernetes nor any Kubernetes admin to be able to see the value of our environment variables - at no time: neither during the runtime nor during the startup time. Of course, only our original Python program should be able to be able to access the value. Any modification of the Python program must be detected.

To do so, we define environment variables in the following way:

- `API_PASSWORD` is an API password and should not be known by anybody. Hence, we ask SCONE CAS (Configuration and Attestation Service) to randomly select it inside an enclave.
  - We define a secret with name `password` as part of the secrets section. This has a length of 10 characters that are randomly selected by CAS.
  - The value of this secret can be referred to by "$$SCONE::password". This value is only available for our Python program. In general, we permit to share secrets amongst the services of the same application mesh only.
  - We define this locally in the manifest for this service. Hence, we define it in section `local` - this cannot be modified in the `Meshfile` (i.e., a manifest that describes how to connect services).
- `API_USER` is an environment variable that is defined in the `Meshfile` . Hence, we add it to the `global` section. We could define a default value in the 


We build the confidential container image with the help of the `build` section:

- `name`: define the name of this service
- `kind`: `Python says that we need a Python engine to execute this program
- `to`: is the name of the generated image
- `pwd`: the working directory in which our Python program will be located
- `command`:  this is the command line. This is protected to ensure that an adversary cannot change the arguments of our program. Changing the arguments would permit the adversary, for example, to print the value of the environment variables.
- `copy`: a list of files or directories to copy into the image.


```yml
apiVersion: scone/5.8
kind: genAppImage

# define environment variables
#  - local ones are only visible for this service
#  - global ones are defined for all services in a mesh

environment:
  local:
    - name: API_PASSWORD # get value from Meshfile
      value: "$$SCONE::password"  # my password
  global:     # values defined/overwritten in Meshfile
    - name: API_USER  # must be define in Meshfile

   # define some key/value pairs used in handlebars  


# define secrets that are managed by CAS - not visible to the outside
secrets:
  global: 
  - name: password
    kind: ascii
    size: 10

build:
  name: python_hello_user
  kind: python
  to: registry.scontain.com:5050/cicd/python_hello_user:latest
  pwd: /python
  command: python3 print_env.py
  copy:
    - print_env.py
```

## Building a Confidential Application

A cloud-native application typically consists of multiple services. In this example, we start with one service.

To run an application, we need to specify which CAS instance we want to use. Actually, we typically can use multiple CAS instances for various aspects.

TODO: remove alias by having a default alias in case it is not given.

Each application must define its own unique CAS namespace. This could have the same name as the namespace that we use to run this application in Kubernetes.

We can define the environment variables that are marked as `global` by the individual services. If no default value was given, we must define a value here.

Todo: `key` will change to `name`

The service section describes the set of services from which this application is composed of:

- `name`: is a unique name of this service
- `image`: is the name of the image.

```yml
apiVersion: scone/5.8
kind: mesh

cas:
  - name: cas # cas used to store the policy of this application
    alias: ["image", "security", "access", "attestation"] # use alias in case CAS instance has multiple roles
    cas_url: edge.scone-cas.cf  # exported as {{cas_cas_cas_url}}
    tolerance: "--only_for_testing-trust-any --only_for_testing-debug  --only_for_testing-ignore-signer -C -G -S"

policy:
  namespace: myPythonApp    # namespace on CAS instance `cas`

# define environment variables   
env:
  - key: API_USER 
    value: myself


services:
  - name: python_app
    image: registry.scontain.com:5050/cicd/python_hello_user:latest
```

## Setup

In case you want to run it from your development machine inside of a container,
you can define an `alias`:

```bash
alias scone="docker run -it --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v \"$HOME/.docker:/root/.docker\" \
    -v \"$HOME/.cas:/root/.cas\" \
    -v \"$HOME/.scone:/root/.scone\" \
    -v \"\$PWD:/root\" \
    -w /root \
    registry.scontain.com:5050/cicd/sconecli:latest"
```

Add this to you shell configuration file (like `.bashrc`).

### Example

Depending what Manifest you apply, different command line options might be available.
To get a list of options, for a given manifest, you can execute:

```bash
scone apply -m Appfile.yml --help
```

## Building a Service Image

We can now apply a manifest as follows:

```bash
scone apply -m Appfile.yml 
```
