# Build the drone executable on a x64 Linux host:
#
#     go build --ldflags '-extldflags "-static"' -o drone_static
#
#
# Alternate command for Go 1.4 and older:
#
#     go build -a -tags netgo --ldflags '-extldflags "-static"' -o drone_static
#
#
# Build the docker image:
#
#     docker build --rm=true -t drone/drone .

## Built from cloudnautique/drone fork on github.

FROM busybox

LABEL vendor="Rancher Labs, Inc" \
	com.rancher.version="v0.5-dec16-1" \
	com.rancher.repo="https://github.com/rancher/catalog-dockerfiles"

EXPOSE 8000
ENV DATABASE_DRIVER=sqlite3
ENV DATABASE_CONFIG=/var/lib/drone/drone.sqlite


# Pulled from centurylin/ca-certs source.
ADD https://raw.githubusercontent.com/CenturyLinkLabs/ca-certs-base-image/master/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY drone_static /drone_static
COPY ./scripts/*.sh /opt/rancher/scripts/
RUN chmod +x /opt/rancher/scripts/*.sh

# default to server though it could also be 'agent'
ENTRYPOINT ["/opt/rancher/scripts/rancher_drone_entrypoint.sh"]
CMD ["server"]

ADD Dockerfile /opt/rancher/
