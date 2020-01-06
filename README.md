# Continuous Integration Platform using Docker Containers: Jenkins & Chef Server
=============

If you are running [docker-compose](https://github.com/sharmamitul/ci-docker-img/blob/master/docker-compose.yml) command first time on your computer, it might take some time to download all images. We have set up the continous integration environment to 
deploy the latest check-in code from [Hello World](https://github.com/sharmamitul/JavaProject) master branch via [Chef cookbook](https://github.com/sharmamitul/helloword-chef) onto Dev/Prod environment. 


### Here’s Tools Links

| **Tools** | **Link** | **Credentials** |
|---|---|---|
| **Jenkins**  | http://${docker-machine ip default}:8080/ | No Credentials |
| **Chef Server**  | https://${docker-machine ip default}/ | Admin/p@ssw0rd1 |

### Github source code links

| **Source Code** | **GitHub Link** |
|---|---|
| **Java Hello World Program**  | [Java code](https://github.com/sharmamitul/JavaProject) | 
| **Docker Images**  | [Docker Source Code](https://github.com/sharmamitul/ci-docker-img) | 
| **Chef CookBook**  | [Chef Cookbook](https://github.com/sharmamitul/helloword-chef) | 

### Description of tools & script, how’s working here 

Please run ./deploy.sh --help command for more details, defined multiple function to perform multiple operations. 

Quick details about deploy.sh script functions

EXAMPLES:

Configure passwordless sudo:
        $ deploy -u

   Add SSH key:
        $ deploy -k

   Configure secure SSH:
        $ deploy -s

   Install Docker v${DOCKER_VERSION}:
        $ deploy -d

   Pull necessary Docker images:
        $ deploy -l

   Setting up bootstrap environment:
        $ deploy -c

   Bootstrapping the node
        $ deploy -b

   Moving .War file to Prod/Dev environment 
       $ deploy -w      

   Uploading chef cookbook to local server
       $ deploy -U      

   Updating host file  
      $ deploy -H      

   Configure everything together:
        $ deploy -a
