ARG UBUNTU_RELEASE=25.04
ARG USER=app
ARG UID=101
ARG GROUP=app
ARG GID=101
ARG CHISEL_VERSION=1.1.0

FROM public.ecr.aws/ubuntu/ubuntu:25.04_edge AS builder
ARG USER
ARG UID
ARG GROUP
ARG GID
ARG TARGETARCH
ARG CHISEL_VERSION
SHELL ["/bin/bash", "-oeux", "pipefail", "-c"]
ADD https://github.com/canonical/chisel/releases/download/v${CHISEL_VERSION}/chisel_v${CHISEL_VERSION}_linux_${TARGETARCH}.tar.gz chisel.tar.gz
RUN tar -xvf chisel.tar.gz -C /usr/bin/
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates \
        ca-certificates-java \
        binutils \
        openjdk-17-crac-jdk \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN jlink --no-header-files --no-man-pages --strip-debug \
    --add-modules \
java.base,java.datatransfer,java.desktop,java.instrument,\
java.logging,java.management,java.management.rmi,java.naming,\
java.prefs,java.rmi,java.security.sasl,java.xml,jdk.incubator.foreign,\
jdk.incubator.vector,jdk.internal.vm.ci,jdk.jfr,jdk.management,\
jdk.management.jfr,jdk.management.agent,jdk.net,jdk.nio.mapmode,\
jdk.sctp,jdk.unsupported,jdk.naming.rmi,java.se,java.net.http,\
java.scripting,java.security.jgss,java.smartcardio,java.sql,\
java.sql.rowset,java.transaction.xa,java.xml.crypto,jdk.accessibility,\
jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.httpserver,\
jdk.jsobject,jdk.localedata,jdk.naming.dns,jdk.security.auth,\
jdk.security.jgss,jdk.xml.dom,jdk.zipfs,java.compiler,\
jdk.internal.vm.compiler,jdk.internal.vm.compiler.management,\
jdk.jdwp.agent,jdk.jcmd,jdk.attach,jdk.internal.jvmstat \
    --output /opt/java

RUN cp /usr/lib/jvm/java-17-openjdk-crac-amd64/lib/criu /opt/java/lib/criu

WORKDIR /opt/java
RUN tar zcvf legal.tar.gz legal && rm -r legal

RUN mkdir -p /rootfs \
    && chisel cut --release=ubuntu-24.10 --root /rootfs \
        libc6_libs \
        libgcc-s1_libs \
        libstdc++6_libs \
        zlib1g_libs \
        libgraphite2-3_libs \
        libglib2.0-0t64_core \
        base-files_bin \
        base-files_chisel \
	libgnutls30t64_libs
RUN install -d -m 0755 -o $UID -g $GID /rootfs/home/$USER \
    && mkdir -p /rootfs/etc \
    && echo -e "root:x:0:\n$GROUP:x:$GID:" >/rootfs/etc/group \
    && echo -e "root:x:0:0:root:/root:/noshell\n$USER:x:$UID:$GID::/home/$USER:/noshell" >/rootfs/etc/passwd
RUN mkdir -p /rootfs/opt \
    && cp -r /opt/java/ /rootfs/opt/java/

WORKDIR /rootfs
RUN ln -s --relative opt/java/bin/java usr/bin/

RUN setcap cap_checkpoint_restore+eip /rootfs/opt/java/lib/criu
RUN chown root:root /rootfs/opt/java/lib/criu
RUN chmod u+s /rootfs/opt/java/lib/criu

FROM scratch
ARG USER
ARG UID
ARG GID
USER $UID:$GID
COPY --from=builder /rootfs /

# Workaround for https://github.com/moby/moby/issues/38710
COPY --from=builder --chown=$UID:$GID /rootfs/home/$USER /home/$USER
ENV JAVA_HOME /opt/java/

ENTRYPOINT ["/opt/java/bin/java"]
