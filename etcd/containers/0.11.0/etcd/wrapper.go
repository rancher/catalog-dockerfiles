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
  "os/exec"
  "io/ioutil"
  "regexp"
)

const (
  backupBaseDir = "/data-backup"
  backupFormat = "data.20060102.150405"
)

var backupRegexp *regexp.Regexp

func init() {
  backupRegexp = regexp.MustCompile(`^data.[0-9]{8}.[0-9]{6}$`)
}

func main() {
  app := cli.NewApp()
  app.Name = "Etcd Wrapper"
  app.Usage = "Utility services for Etcd clusters"
  app.Commands = []cli.Command{
    HealthcheckProxyCommand(),
    RollingBackupCommand(),
  }
  app.Run(os.Args)
}

func HealthcheckProxyCommand() cli.Command {
  return cli.Command{
    Name:  "healthcheck-proxy",
    Usage: "Proxy health checks with a waiting period to ensure raft index has caught up with the cluster",
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

func RollingBackupCommand() cli.Command {
  return cli.Command{
    Name:  "rolling-backup",
    Usage: "Perform rolling backups",
    Action: RollingBackupAction,
    Flags: []cli.Flag{
      cli.DurationFlag{
        Name:  "period",
        Usage: "Perform backups at this time interval",
        Value: 5 * time.Minute,
      },
      cli.DurationFlag{
        Name:  "retention",
        Usage: "Retain backups for this time interval",
        Value: 24 * time.Hour,
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

func RollingBackupAction(c *cli.Context) error {
  backupPeriod := c.Duration("period")
  retentionPeriod := c.Duration("retention")

  log.Printf("Performing backups every %v with a %v retention period", backupPeriod, retentionPeriod)

  backupTicker := time.NewTicker(backupPeriod)
  for {
    select {
    case backupTime := <-backupTicker.C:
      CreateBackup(backupTime)
      PurgeBackups(backupTime, retentionPeriod)
    }
  }
  return nil
}

func CreateBackup(t time.Time) {
  for retry := true; retry == true; {
    dataDir := "/data/data.current"
    backupDir := fmt.Sprintf("%s/data.%d%02d%02d.%02d%02d%02d", backupBaseDir,
      t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), t.Second())

    cmd := exec.Command("etcdctl", "backup", "--data-dir", dataDir, "--backup-dir", backupDir)

    startTime := time.Now()
    if err := cmd.Run(); err != nil {
      log.Println(err.Error())
      time.Sleep(15 * time.Second)
    } else {
      log.Printf("Created backup in %v", time.Now().Sub(startTime))
      retry = false
    }
  }
}

func PurgeBackups(backupTime time.Time, retentionPeriod time.Duration) {
  cutoffTime := backupTime.Add(retentionPeriod * -1)

  files, err := ioutil.ReadDir(backupBaseDir)
  if err != nil {
    log.Fatal(err)
  }
  for _, file := range files {
    if !file.IsDir() {
      continue
    }

    if !backupRegexp.MatchString(file.Name()) {
      log.Printf("unrecognized backup: %v", file.Name())      
    } else {
      backupTime, err2 := time.Parse(backupFormat, file.Name())
      if err2 != nil {
        log.Println(err2)
      } else if backupTime.Before(cutoffTime) {
        toDelete := fmt.Sprintf("%s/%s", backupBaseDir, file.Name())
        cmd := exec.Command("rm", "-rf", toDelete)

        if err := cmd.Run(); err != nil {
          log.Printf("Couldn't delete backup %v", toDelete)
        } else {
          log.Printf("Deleted backup %v", toDelete)
        }
      }
    }
  }
}

// TODO (llparse): inherit this function from giddyup
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
