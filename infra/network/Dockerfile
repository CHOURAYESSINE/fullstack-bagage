FROM alpine:3.23
RUN apk add --no-cache wireguard-tools iproute2 iptables openssl curl python3
COPY *.sh *.py /lab/
RUN chmod 755 /lab/*.sh
WORKDIR /lab
CMD ["sleep", "infinity"]
