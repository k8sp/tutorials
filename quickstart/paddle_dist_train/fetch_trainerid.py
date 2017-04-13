#!/usr/local/bin/python

import requests
import os
import socket
import time
tokenpath = '/var/run/secrets/kubernetes.io/serviceaccount/token'
tokenfile = open(tokenpath, mode='r')
token = tokenfile.read()
Bearer = "Bearer " + token
headers = {"Authorization": Bearer}
uri = "https://%s:%s/api/v1/namespaces/%s/pods?labelSelector=job-name=%s" % ( \
    os.getenv("KUBERNETES_SERVICE_HOST"), \
    os.getenv("KUBERNETES_SERVICE_PORT_HTTPS"), \
    os.getenv("JOB_NAMESPACE"), \
    os.getenv("JOB_NAME"))
def isPodAllRunning(podlist):
    '''
    check all pod is running
    '''
    if podlist.has_key("items") and podlist["items"] == None:
        return False
    require = int(os.getenv("TRAINER_COUNT"))
    running = 0
    for pod in podlist["items"]:
        if pod["status"]["phase"] == "Running":
            running += 1
    if require == running:
        return True
    return False

def getPodList():
    return requests.get(uri, headers=headers, verify=False).json()

podlist = getPodList()
# need to wait until all pods are running
while not isPodAllRunning(podlist):
    time.sleep(20)
    podlist = getPodList()

ips = []
for pod in podlist["items"]:
    ips.append(pod["status"]["podIP"])
ips.sort()
idMap = {}
localIP = socket.gethostbyname(socket.gethostname())
for i in range(len(ips)):
    if ips[i] == localIP:
        print i
        break
