# logspout-logstash
From https://github.com/looplab/logspout-logstash

A minimalistic adapter for github.com/gliderlabs/logspout to write to Logstash UDP

Use by setting `ROUTE_URIS=logstash://host:port` to the Logstash host and port for UDP.

In your logstash config, set the input codec to `json` e.g:

input {
  udp {
    port => 5000
    codec => json
  }
}

