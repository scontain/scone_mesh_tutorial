# SCONE MESH EXAMPLE

## Hello World!

We start with a simple "Hello World" example, in which we pass a user ID and a password to a simple Python program. Neither cloud provider nor system admins will be able to see the parameters or change the program.

This program could look as follows:

```python
import os

# Get some environment variables
API_USER = os.getenv('API_USER')
API_PASSWORD = os.environ.get('API_PASSWORD')

# Exit with error if one is not defined
if API_USER == None or API_PASSWORD == None:
    print("Not all required environment variables are defined!")
    exit(1)

# Print API_USER - this is - unlike the API_PASSWORD - not confidential
print(f"Hello '{API_USER}' - thanks for passing along the API_PASSWORD")
```

## Objectives

Our objective is that it must be impossible both:

1. to view and modify the password, and
2. to modify the program

by both  

1. a system admin or any other user with root access, and
2. a cloud provider or anybody else with physical access to the hardware.

Using SCONE it is also possible to protect the code confidentiality so that nobody can view the program, but we do not include this feature in this example.

## Create Manifest Files

The first thing you need to do is to create the manifest files describing your services and how they should be connected in your application.
The manifests are used to build confidential container images and to generate and upload the security policy for your confidential application. This is done in one **service manifest** file per service and one **mesh manifest** file (a.k.a. **Meshfile**), which is used to generate the security policies and global variables.

In this example, there is only one service and both its service and mesh manifest files have been created for you (`service.yml` and `mesh.yml`).
Note that you do not need a service manifest for **curated confidential service** like `memcached`, `nginx`, `MariaDB`, etc: the images already contain all required information.  

## Quick Start

Once you have created your manifest files, you only need to perform the following three steps to build and run your confidential application on Kubernetes:

1. Build the service OCI container image:

**TODO** `change from -m to -f`

```bash
sconectl apply -f service.yml
```

2. Build and upload the security policy for the application using:

```bash
sconectl apply -f mesh.yml
```

3. The second step generates a `helm` chart and you can start this application by executing:

```bash
helm install python_app target/helm
```

That's it! But in case you are interested in what is going on under the hood, we explain the steps in detail below.

### Note

Ensure that the container images that are generated in step 1. are not yet permitted to run. They are only permitted to run after the security policies are created or updated in step 2. Ensure that the images are only deployed after step 2. For example, you might push the images only after step 2 to the cluster.

## Building a Confidential Image

We can build a confidential container image with the help of a manifest of kind `genImage`.

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

**TODO** `change from genAppImage to genImage`

```yml
apiVersion: scone/5.8
kind: genImage

# define environment variables
#  - local ones are only visible for this service
#  - global ones are defined for all services in a mesh

environment:
  local:
    - name: API_PASSWORD # required by Python program
      value: "$$SCONE::password"  # my password
  global:     # global values are defined/overwritten in Meshfile
    - name: API_USER  # required by Python program

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

**TODO** `add default alias and check that cas is always defined`

```yml
apiVersion: scone/5.8
kind: mesh

cas:
  - name: cas # cas used to store the policy of this application
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
alias sconectl="docker run -it --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v \"$HOME/.docker:/root/.docker\" \
    -v \"$HOME/.cas:/root/.cas\" \
    -v \"$HOME/.scone:/root/.scone\" \
    -v \"\$PWD:/root\" \
    -w /root \
    registry.scontain.com:5050/cicd/sconecli:latest"
```

Add this to you shell configuration file (like `.bashrc`). Alternatively, we also provide a simple Rust script to implement this functionality.

**TODO** `write simple rust script instead of using alias`

### Example

Depending what Manifest you apply, different command line options might be available.
To get a list of options, for a given manifest, you can execute:

```bash
scone apply -f Appfile.yml --help
```

## Building a Service Image

We can now apply a manifest as follows:

```bash
scone apply -f Appfile.yml 
```
