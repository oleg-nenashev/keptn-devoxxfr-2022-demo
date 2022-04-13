# Devoxx France 2022 - Keptn & Prometheus demo

This demo shows Keptn and Prometheus operating together...
in a single-container Kubernetes cluster provided by K3D.
The demo demonstrates monitoring project SLIs with Prometheus and Keptn,
and automatic remediation in the case the settings are violated.

## Prerequisites

- Docker. Docker for Windows and MacOS should work too
- make (one for Windows is fine too)

## Quick Start

First of all, build the demo image:

```bash
make build
```

Then, run the demo:

```bash
make run
```

Expect install to take about 10 minutes.
Once complete, Keptn is available on `http://localhost`

### Keptn in a Docker Container

This demo creates a single container with:
- A k8s cluster inside
- Helm is installed
- Prometheus is installed to the `monitoring` namespace
- Keptn installed to the `keptn` namespace.
  Prometheus and Job Executor service are also included.
- Keptn bridge and API are exposed on localhost on port `80`: `http://localhost`
- A demo "hello world" project is created
- Automatically runs a first "hello world" sequence for you

If you need additional Keptn services, just `docker exec -it ${CONTAINER_NAME} /bin/sh` then use `helm` to install services. `kubectl` is also available.

## What Happened?

- k3d, Helm and Keptn into the docker container and exposed it to your localhost
- We also installed the job executor service. Keptn orchestrates other tools and services are a cornerstone of how it does that. Services abstract the details of dealing with the product and leave you free to get on with your day.
- Once everything was installed, a cloudevent was sent into Keptn's API (see `helloevent.cloudevent.json`)
- That cloudevent has a `type` in a specific format that tells Keptn to trigger the `hello` sequence in the `demo` stage (see `shipyard.yaml`)
- Keptn now knows it needs to trigger the task inside the `hello` sequence. So Keptn crafts and distributes another cloudevent, automatically on our behalf (`sh.keptn.event.hello-world.triggered`)
- It is this `hello-world.triggered` event that the job executor service is listening for
- The job executor looks for it's configuration (see `jobconfig.yaml`) and so spins up the `alpine` image to say hello!


The power of Keptn is that we've split our process (defined in the `shipyard.yaml`) from the tooling.

Want to get a Slack message instead of a container saying hello? Just swap your services and listen for the same `hello-world.triggered` event. You don't need to know how the Slack APIs work. Someone else has done that for you. Just uninstall the Job Executor Service and install the [notification service](https://github.com/keptn-contrib/notification-service).

Want to trigger a webhook? Just configure the webhook service to send an outbound POST to your tool.

The possibilities are endless.


## Troubleshooting

### Windows Users

Windows users need to use WSL2 and set their .wslconfig accordingly.

`wsl --status` should show: `Default Version: 2`

Also make sure you create a file called `.wslconfig` and save to `c:\Users\you\.wslconfig`.

You can increase the limits if you have more resources available, but this is the minimum spec you need for stability:
```
# Settings apply across all Linux distros running on WSL 2
[wsl2]

# Limit memory to 8GB
memory=8GB

# Limit processors to 4 logical processors
processors=8
```

### WSL Kernel Update

Docker desktop usually forces you to upgrade the WSL kernel during installation but if not:

1. Open a `cmd` window as **Administrator** and type `wsl --update` then `wsl --shutdown` and restart Docker Desktop

![image](https://user-images.githubusercontent.com/26523841/155234144-37ac614e-7535-4ca9-a1b5-8e0b0c7b1636.png)

If in doubt, stop all running containers and run `docker system prune` to clean up unused stuff.

### Still Stuck?

Join [Keptn Slack](https://slack.keptn.sh) and ask in `#help`
