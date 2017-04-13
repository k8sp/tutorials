#!/usr/local/bin/python

import requests
import os
import socket
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
#print "fetch pod info, uri: %s" % uri
pod_list = requests.get(uri,
                        headers=headers,
                        verify=False).json()
ips = []
for pod in pod_list["items"]:
    ips.append(pod["status"]["podIP"])
ips.sort()
idMap = {}
localIP = socket.gethostbyname(socket.gethostname())
for i in range(len(ips)):
    if ips[i] == localIP:
        print i
        break
