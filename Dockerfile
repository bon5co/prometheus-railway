FROM golang:1.24-alpine AS hash
WORKDIR /src
COPY bcrypt-hash/ .
RUN go get golang.org/x/crypto/bcrypt@v0.31.0 && \
    CGO_ENABLED=0 go build -ldflags='-s -w' -o /bcrypt-hash .

FROM prom/prometheus:v3.15.0@sha256:efd719c99d83b060d9daefdcf00360461adf279f45ef5391f8d111892118753e
USER root
COPY --from=hash /bcrypt-hash /usr/local/bin/bcrypt-hash
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
