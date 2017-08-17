package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"time"

	log "github.com/Sirupsen/logrus"
	"github.com/urfave/cli"
)

const (
	dataDir       = "/data/etcd"
	backupBaseDir = "/backup"
	backupRetries = 4
)

func init() {
	log.SetOutput(os.Stderr)
}

func main() {
	err := os.Setenv("ETCDCTL_API", "3")
	if err != nil {
		log.Fatal(err)
	}

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
		Name:   "healthcheck-proxy",
		Usage:  "Proxy health checks with a waiting period to ensure raft index has caught up with the cluster",
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
				Name:   "debug",
				Usage:  "Verbose logging information for debugging purposes",
				EnvVar: "RANCHER_DEBUG",
			},
		},
	}
}

func RollingBackupCommand() cli.Command {
	return cli.Command{
		Name:   "rolling-backup",
		Usage:  "Perform rolling backups",
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
				Name:   "debug",
				Usage:  "Verbose logging information for debugging purposes",
				EnvVar: "RANCHER_DEBUG",
			},
		},
	}
}

func SetLoggingLevel(debug bool) {
	if debug {
		log.SetLevel(log.DebugLevel)
	} else {
		log.SetLevel(log.InfoLevel)
	}
}

func ProxyAction(c *cli.Context) error {
	SetLoggingLevel(c.Bool("debug"))

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		err := HealthCheck("tcp://127.0.0.1:2379", 5*time.Second)

		if err == nil {
			fmt.Fprintf(w, "OK")
			log.Debug("HealthCheck succeeded")

		} else {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			log.WithFields(log.Fields{
				"error": err.Error(),
			}).Debug("HealthCheck failed")
		}
	})

	time.Sleep(c.Duration("wait"))
	// TODO (llparse): determine when raft index has caught up with other nodes in metadata
	return http.ListenAndServe(c.String("port"), nil)
}

func RollingBackupAction(c *cli.Context) error {
	SetLoggingLevel(c.Bool("debug"))

	backupPeriod := c.Duration("period")
	retentionPeriod := c.Duration("retention")

	log.WithFields(log.Fields{
		"period":    backupPeriod,
		"retention": retentionPeriod,
	}).Info("Initializing Rolling Backups")

	backupTicker := time.NewTicker(backupPeriod)
	for {
		select {
		case backupTime := <-backupTicker.C:
			CreateBackup(backupTime)
			DeleteBackups(backupTime, retentionPeriod)
		}
	}
	return nil
}

func CreateBackup(t time.Time) {
	var err error
	failureInterval := 15 * time.Second
	backupName := fmt.Sprintf("%s_etcd", t.Format(time.RFC3339))
	backupDir := fmt.Sprintf("%s/%s", backupBaseDir, backupName)

	for retries := 0; retries <= backupRetries; retries += 1 {
		if retries > 0 {
			time.Sleep(failureInterval)
		}

		// FIXME! either get container ips (ideal) or service/stack name (dns)
		// curl -H 'Accept: application/json' http://169.254.169.250/2016-07-29/self/stack/etcd/services/etcd/containers | jq -r .[].primary_ip
		// only use .[].state == 'running'
		cmd := exec.Command("etcdctl", "snapshot", "save", "--endpoints", "etcd.etcd:2379", backupDir)

		startTime := time.Now()
		data, err := cmd.CombinedOutput()
		endTime := time.Now()

		if err != nil {
			log.WithFields(log.Fields{
				"attempt": retries + 1,
				"error":   err,
				"data":    string(data),
			}).Warn("Backup failed")

		} else {
			log.WithFields(log.Fields{
				"name":    backupName,
				"runtime": endTime.Sub(startTime),
			}).Info("Created backup")
			break
		}
	}

	if err != nil {
		log.WithFields(log.Fields{
			"name": backupName,
		}).Fatal("Couldn't create backup!")
	}
}

func DeleteBackups(backupTime time.Time, retentionPeriod time.Duration) {
	files, err := ioutil.ReadDir(backupBaseDir)
	if err != nil {
		log.WithFields(log.Fields{
			"dir":   backupBaseDir,
			"error": err,
		}).Fatal("Can't read backup directory")
	}

	cutoffTime := backupTime.Add(retentionPeriod * -1)

	for _, file := range files {
		if file.IsDir() {
			log.WithFields(log.Fields{
				"name": file.Name(),
			}).Warn("Ignored directory, expecting file")
			continue
		}

		backupTime, err2 := time.Parse(time.RFC3339, strings.Split(file.Name(), "_")[0])
		if err2 != nil {
			log.WithFields(log.Fields{
				"name":  file.Name(),
				"error": err2,
			}).Warn("Couldn't parse backup")

		} else if backupTime.Before(cutoffTime) {
			DeleteBackup(file)
		}
	}
}

func DeleteBackup(file os.FileInfo) {
	toDelete := fmt.Sprintf("%s/%s", backupBaseDir, file.Name())

	cmd := exec.Command("rm", "-r", toDelete)

	startTime := time.Now()
	err2 := cmd.Run()
	endTime := time.Now()

	if err2 != nil {
		log.WithFields(log.Fields{
			"name":  file.Name(),
			"error": err2,
		}).Warn("Delete backup failed")

	} else {
		log.WithFields(log.Fields{
			"name":    file.Name(),
			"runtime": endTime.Sub(startTime),
		}).Info("Deleted backup")
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
