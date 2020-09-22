package main

import (
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"gopkg.in/mgo.v2"
)

var coll *mgo.Collection
var sleep = time.Sleep
var logFatal = log.Fatal
var logPrintf = log.Printf
var httpListenAndServe = http.ListenAndServe
var serviceName = "go-demo"

type Person struct {
	Name string
}

var (
	histogram = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Subsystem: "http_server",
		Name:      "resp_time",
		Help:      "Request response time",
	}, []string{
		"service",
		"code",
		"method",
		"path",
	})
)

func main() {
	if len(os.Getenv("SERVICE_NAME")) > 0 {
		serviceName = os.Getenv("SERVICE_NAME")
	}
	RunServer()
}

func init() {
	prometheus.MustRegister(histogram)
}

// TODO: Test

func RunServer() {
	mux := http.NewServeMux()
	mux.HandleFunc("/demo/hello", HelloServer)
	mux.HandleFunc("/demo/random-error", RandomErrorServer)
	mux.Handle("/metrics", prometheusHandler())
	logFatal("ListenAndServe: ", httpListenAndServe(":8080", mux))
}

func HelloServer(w http.ResponseWriter, req *http.Request) {
	start := time.Now()
	defer func() { recordMetrics(start, req, http.StatusOK) }()

	logPrintf("%s request to %s\n", req.Method, req.RequestURI)
	delay := req.URL.Query().Get("delay")
	if len(delay) > 0 {
		delayNum, _ := strconv.Atoi(delay)
		sleep(time.Duration(delayNum) * time.Millisecond)
	}
	io.WriteString(w, "hello, world!\n")
}

func RandomErrorServer(w http.ResponseWriter, req *http.Request) {
	code := http.StatusOK
	start := time.Now()
	defer func() { recordMetrics(start, req, code) }()

	logPrintf("%s request to %s\n", req.Method, req.RequestURI)
	rand.Seed(time.Now().UnixNano())
	n := rand.Intn(10)
	msg := "Everything is still OK\n"
	if n == 0 {
		code = http.StatusInternalServerError
		msg = "ERROR: Something, somewhere, went wrong!\n"
		logPrintf(msg)
	}
	w.WriteHeader(code)
	io.WriteString(w, msg)
}



var prometheusHandler = func() http.Handler {
	return prometheus.Handler()
}


func recordMetrics(start time.Time, req *http.Request, code int) {
	duration := time.Since(start)
	histogram.With(
		prometheus.Labels{
			"service": serviceName,
			"code":    fmt.Sprintf("%d", code),
			"method":  req.Method,
			"path":    req.URL.Path,
		},
	).Observe(duration.Seconds())
}
