# GlusterFS (3.7.5) Experimental

---

## Purpose

 This is compose file that launches a GlusterFS cluster and creates a replicated data volume.
 
 In this case, think of the `stack` as the trusted storage pool with a single volume. Multiple volumes would be deployed via multiple stacks.
 
The volume will then be mountable as a glusterfs volume.

## Notes

The Stack is not upgradeable between versions, until Rancher supports IP reuse. All new containers get the same IP. Pool scale up is supported, but should only be attempted after an initial deployment's volume is created. Scale up at your own risk. Volume scale up is unsupported, you will need to manually add bricks for new server containers. Scale down is entirely unsupported and will lead to data loss.
 
## How to Use
 
 Launch a new stack with the desired replica count set as `scale` in rancher-compose.yml.
 
 If you wanted a volume that keeps '3' replicas, you would set 
 
```
---
glusterfs-server:
  scale: 3 # replica count
  ...
```

You can define the Gluster Volume name in the metadata section of the glusterfs-server service

```
glusterfs-server:
  ...
  metadata:
    volume_name: "my_volume"
  ...
```

bring up the cluster with rancher-compose, if you would like to use Rancher networking use the setting `network_mode='container:glusterfs-server'` if you would like to mount Gluster from systems outside of Rancher, use `network_mode=host`. When running on the 'host' network, you need to ensure you are running on a secure network otherwise others could gain access to your data. 

`network_mode=<network_mode> rancher-compose -p gluster up`

Once the volume is up you can mount it from a client with:
`mount -t glusterfs <ip of gluster node>:/my_volume /mnt`

*Note: Mounting inside a docker container, it needs `--cap-add SYS_ADMIN --device /dev/fuse:/dev/fuse:rwm ` On the 3.19.x kernel in Ubuntu, there is a bug with Apparmor, that requires the client container have `--privileged` options.






