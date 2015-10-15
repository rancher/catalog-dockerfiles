## Confd Logstash Configuration Generator

---

### Purpose
This creates a minimalistic Docker container that provides /etc/logstash/logstash.conf file via a Volume.

### Build

If you would like to build your own container from scratch


### KEYS

The keyspace is set to:

```
/logstash/config/{INPUTS,FILTERS,OUTPUTS}
```

In order to add a rule the format is:


```
/logstash/config/<section>/<rulename>/<idx> = '{"json": "value"}'

```
where:

**Section**: is either inputs, filters or outputs. These line up to sections of a logstasy.conf file.

**Rulename**: is the name of a logstash input, filter or output. Ie. udp, redis, grok, elasticsearch, etc.

**idx**: is a unique number to the section/rule. This allows multiple entries of the same type. Ie. udp with port 5000 and 5001 would have the same keyspace and unique idx. 


```
  #example(with environment variable backend): 
  LOGSTASH_CONFIG_INPUTS_UDP_0={"port": "5000"}

  # will translate to:
  output {
   udp {
       port => 5000
   }
  }
  ...
```

Currently, this supports top level if conditional(meaning else if/else and nested are not supported right now). The keyspace for a conditional looks like:

```
  /logstash/config/<section>/conditionals/<idx>/condition = <the whole condition>
  /logstash/config/<section>/conditionals/<idx>/<rule>/<idx> = {"json": "value"}
```

sections can have multiple conditionals. They have an index that is unique to the section. The must have a single key 'condition' that contains the entire condition string.

Each condition can have multiple rules. They follow the same rules as above, just nested under the conditionals/<idx> keyspace.


An example of a conditional with rule looks like:

```
 # using environment backend for key
 LOGSTASH_CONFIG_INPUTS_CONDITIONALS_0_CONDITION='if [docker.name] == "logspout"'
 LOGSTASH_CONFIG_INPUTS_CONDITIONALS_0_REDIS_0='{"host": "localhost", "port": "6379", "data_type": "list", "key": "logstash"}'
 
 # Will translate to:
 output {
 	if [docker.name] == "logspout" {
 		redis {
 		    host => localhost
 		    port => 6379
 		    data_type => list
 		    keyh => logstash
 	}
 }
 ...
```




