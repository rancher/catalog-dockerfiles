FROM golang:alpine

RUN apk update && apk add git
RUN go get github.com/urfave/cli

RUN mkdir -p /go/src/etcdhc
WORKDIR /go/src/etcdhc
ADD hcproxy.go .

RUN go build
