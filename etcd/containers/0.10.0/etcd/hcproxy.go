package main

import (
  "github.com/urfave/cli"
  "errors"
  "fmt"
  "net"
  "net/http"
  "net/url"
  "time"
  "os"
  "log"
)

func main() {
  app := cli.NewApp()
  app.Name = "Etcd healthcheck proxy"
  app.Usage = "Ensure Etcd's raft index has caught up with the cluster before reporting healthy"
  app.Commands = []cli.Command{
    ProxyCommand(),
  }
  app.Run(os.Args)
}

func ProxyCommand() cli.Command {
  return cli.Command{
    Name:  "proxy",
    Usage: "Proxy health checks after a waiting period",
    Action: ProxyAction,
    Flags: []cli.Flag{
      cli.StringFlag{
        Name:  "port, p",
        Usage: "Port address to serve proxied health checks on",
        Value: ":2378",
      },
      // This feature flag is to be used for etcd v2.3.7 and earlier
      cli.DurationFlag{
        Name:  "wait",
        Usage: "Wait for a period of time before proxying health checks",
        Value: 120 * time.Second,
      },
      // This feature flag is to be used for etcd v3.0.0 and later
      cli.BoolFlag{
        Name:  "raft",
        Usage: "Wait for raft indeces to all be in range (requires etcd version >= v3.0.0)",
      },
      cli.BoolFlag{
        Name:  "debug",
        Usage: "Verbose logging information for debugging purposes",
        EnvVar: "RANCHER_DEBUG",
      },
    },
  }
}

func ProxyAction(c *cli.Context) error {
  http.HandleFunc("/health", func (w http.ResponseWriter, r *http.Request) {
    err := HealthCheck("tcp://127.0.0.1:2379", 5 * time.Second)

    if err == nil {
      fmt.Fprintf(w, "OK")
      if c.Bool("debug") {
        log.Println("OK")
      }
    } else {
      http.Error(w, err.Error(), http.StatusServiceUnavailable)
      if c.Bool("debug") {
        log.Println(err.Error())
      }
    }
  })

  time.Sleep(c.Duration("wait"))
  // TODO (llparse): determine when raft index has caught up with other nodes in metadata
  return http.ListenAndServe(c.String("port"), nil)
}

func HealthCheck(endpoint string, timeout time.Duration) error {
  url, err := url.Parse(endpoint)
  if err != nil {
    return err
  }

  switch url.Scheme {
  case "tcp":
    var conn net.Conn
    if conn, err = net.DialTimeout(url.Scheme, url.Host, timeout); err != nil {
      return err
    }
    conn.Close()
  case "http", "https":
    client := &http.Client{
      Timeout: timeout,
    }
    var resp *http.Response
    resp, err = client.Get(endpoint)

    switch {
    case err != nil:
      return err
    case resp.StatusCode >= 200 && resp.StatusCode <= 299:
      return nil
    default:
      return errors.New(fmt.Sprintf("HTTP %d\n", resp.StatusCode))
    }
  default:
    return errors.New(fmt.Sprintf("Unsupported URL scheme: %s\n", url.Scheme))
  }
  return nil
}
