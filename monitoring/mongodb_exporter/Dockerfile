FROM alpine:3.4
EXPOSE 9001

COPY mongodb_exporter /bin/mongodb_exporter
RUN chmod +x /bin/mongodb_exporter

ENTRYPOINT [ "/bin/mongodb_exporter" ]
