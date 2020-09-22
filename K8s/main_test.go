package main

import (
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/suite"
)

// Suite

type MainTestSuite struct {
	suite.Suite
}

// Suite

func TestMainUnitTestSuite(t *testing.T) {
	logFatalOrig := logFatal
	logPrintfOrig := logPrintf
	httpListenAndServeOrig := httpListenAndServe
	defer func() {
		logFatal = logFatalOrig
		logPrintf = logPrintfOrig
		httpListenAndServe = httpListenAndServeOrig
	}()
	logFatal = func(v ...interface{}) {}
	logPrintf = func(format string, v ...interface{}) {}
	httpListenAndServe = func(addr string, handler http.Handler) error { return nil }
	suite.Run(t, new(MainTestSuite))
}

func (s *MainTestSuite) SetupTest() {}

// init

func (s *MainTestSuite) Test_SetupMetrics_InitializesHistogram() {
	s.NotNil(histogram)
}

// RunServer

func (s *MainTestSuite) Test_RunServer_InvokesListenAndServe() {
	actual := ""
	httpListenAndServe = func(addr string, handler http.Handler) error {
		actual = addr
		return nil
	}

	RunServer()

	s.Equal(":8080", actual)
}

// RandomErrorServer

func (s *MainTestSuite) Test_HelloServer_WritesOk() {
	req, _ := http.NewRequest("GET", "/demo/random-error", nil)
	w := getResponseWriterMock()

	for i := 0; i <= 3; i++ {
		RandomErrorServer(w, req)
	}

	w.AssertCalled(s.T(), "Write", []byte("Everything is still OK\n"))
}

func (s *MainTestSuite) Test_HelloServer_WritesNokEventually() {
	req, _ := http.NewRequest("GET", "/demo/random-error", nil)
	w := getResponseWriterMock()

	for i := 0; i <= 50; i++ {
		RandomErrorServer(w, req)
	}

	w.AssertCalled(s.T(), "Write", []byte("ERROR: Something, somewhere, went wrong!\n"))
}

// HelloServer

func (s *MainTestSuite) Test_HelloServer_WritesHelloWorld() {
	req, _ := http.NewRequest("GET", "/demo/hello", nil)
	w := getResponseWriterMock()

	HelloServer(w, req)

	w.AssertCalled(s.T(), "Write", []byte("hello, world!\n"))
}

func (s *MainTestSuite) Test_HelloServer_Waits_WhenDelayIsPresent() {
	sleepOrig := sleep
	defer func() { sleep = sleepOrig }()
	var actual time.Duration
	sleep = func(d time.Duration) {
		actual = d
	}
	req, _ := http.NewRequest("GET", "/demo/hello?delay=10", nil)
	w := getResponseWriterMock()

	HelloServer(w, req)

	s.Equal(10*time.Millisecond, actual)
}

type ResponseWriterMock struct {
	mock.Mock
}

func (m *ResponseWriterMock) Header() http.Header {
	m.Called()
	return make(map[string][]string)
}

func (m *ResponseWriterMock) Write(data []byte) (int, error) {
	params := m.Called(data)
	return params.Int(0), params.Error(1)
}

func (m *ResponseWriterMock) WriteHeader(header int) {
	m.Called(header)
}

func getResponseWriterMock() *ResponseWriterMock {
	mockObj := new(ResponseWriterMock)
	mockObj.On("PHeader").Return(nil)
	mockObj.On("Write", mock.Anything).Return(0, nil)
	mockObj.On("WriteHeader", mock.Anything)
	return mockObj
}
