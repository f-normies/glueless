FROM alpine:latest
ENV VERSION=v3.1.8
WORKDIR /hiddify
RUN apk add curl tar gzip libc6-compat iptables ip6tables redsocks

RUN echo "architecture: $(apk --print-arch)" && \    
    case "$(apk --print-arch)" in \
            x86_64) ARCH=amd64 ;; \
            i386|x86) ARCH=386 ;; \
            aarch64) ARCH=arm64 ;; \
            armv7) ARCH=armv7 ;; \
            armv6|armhf) ARCH=armv6 ;; \
            armv5) ARCH=armv5 ;; \
            s390x) ARCH=s390x ;; \
            *) echo "Unsupported architecture: $(apk --print-arch) $(uname -m)" && exit 1 ;; \
        esac && \
        echo "Downloading https://github.com/hiddify/hiddify-core/releases/download/${VERSION}/hiddify-cli-linux-$ARCH.tar.gz" && \
        curl -L -o hiddify-cli.tar.gz https://github.com/hiddify/hiddify-core/releases/download/${VERSION}/hiddify-cli-linux-$ARCH.tar.gz && \
        tar -xzf hiddify-cli.tar.gz && rm hiddify-cli.tar.gz
COPY hiddify.sh .
COPY healthcheck.sh .
COPY redsocks.conf .
RUN chmod +x hiddify.sh && chmod +x healthcheck.sh

EXPOSE 12334
EXPOSE 12335
EXPOSE 16756
EXPOSE 16450

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /hiddify/healthcheck.sh

ENTRYPOINT [ "/hiddify/hiddify.sh" ]