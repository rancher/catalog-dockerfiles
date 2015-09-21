## HADOOP + YARN

---- 
### Description: 

This compose template stands up HDFS and Yarn services across a cluster of machines. The template is written generically from a scheduling perspective. Configuration is statically set at the moment aside from dynamic environment information provided by Rancher metadata service.

The HDFS and Yarn Clusters are brought up with single node masters. 
 

### Services

HDFS:

* namenode-primary
* datanode

Yarn:

* yarn-resourcemanager
* yarn-nodemanager
* jobhistoryserver

Configuration:

Each of the primary services has 1-3 sidekicks that generate configuration / bootstrap the environment.

Users created:

* hdfs
* yarn
* mapred
* hadoop - HDFS home dir /users/hadoop

By default you will have 

1 Namenode
1 YARN Resource manager
1 HDFS-Datanode container
1 YARN-Nodemanager container


### Bringing it up

You can use `rancher-compose -p hadoop up` and it will bring up all of the services. You can edit the scale ahead of time if you wish to bring up more then one datanode and yarn-nodemanager. 

You'll be able to view the admin pages for each service

* HDFS: `http://<host ip of namenode>:50070`
* Yarn: `http://<host ip of yarn-resourcemanager>:8088`

### Known issues

* Still trying to work through getting to the Logs via the links in Yarn manager. IP translation from Rancher 10.x.x.x ips to the Host IPs seems to work but is less then ideal.

* Need stress testing Running across the rancher network. Perhaps go with an alternate config to use host networking.

* Need to dynamically add configuration parameters for tunning purposes.

* HA Configurations for Namenode and Yarn.



### Building the containers

If you want to build your own containers, you can run the build.sh script in the containers directory:

`./containers/build.sh <namespace>`

If you want to push the images to the registry you can add `true` after the namespace. Its a very basic script.




