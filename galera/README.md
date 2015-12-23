#MariaDB Galera Cluster

## Purpose
Run a Galera cluster on Rancher for HA MySQL.

### How to use
The main image behaves similarly to the standard MariaDB image. You can set the following variables:

```
MYSQL_ROOT_PASSWORD (required)
MYSQL_DATABASE (Creates a DB with this name)
MYSQL_USER (Creates a user)
MYSQL_PASSWORD (users password)
```

The configuration image is running confd and pulling from metadata
The following settings are configured dynamically/automatically:


```
server-id
log-bin 
bind-address 
report_host
wsrep_node_name
wsrep_cluster_name
```

Users can specify configuration for the [mysqld] info using Rancher Metadata

Configuration lines from my.cnf are directly inserted into `/etc/mysql/conf.d/001-galera.cnf`, no format change. 

Defaults:

```
mysqld: |
 innodb_file_per_table = 1
 innodb_autoinc_lock_mode=2
 query_cache_size=0
 query_cache_type=0
 innodb_flush_log_at_trx_commit=0
 binlog_format=ROW
 default-storage-engine=innodb
 wsrep_provider=/usr/lib/galera/libgalera_smm.so
 wsrep_provider_options="gcache.size = 2G"
 wsrep_sst_method=mysqldump
 wsrep_sst_auth=root:password
 progress=1
```

## Cluster shutdown

If/When a cluster is fully shutdown or stopped, when it comes up it will not elect a leader on its own. You need to
open a shell to the DB and run: `SET GLOBAL wsrep_provider_options='pc.boostrap=YES';` on the most advanced node.

See [Galera documentation](http://galeracluster.com/documentation-webpages/quorumreset.html#id2) for more details.

## ToDos

* Create an Rsync Sidekick for data level transfers. Using mysqldump at the moment which is not the fastest and has some drawbacks when adding new nodes.
* Add CMON?



