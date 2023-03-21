FROM fedora:37 AS build-ocpdoom
WORKDIR /go/src/ocpdoom
ADD go.mod .
ADD ocpdoom.go .
RUN dnf install golang -y &&  dnf clean all
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ocpdoom .

FROM fedora:37 AS build-essentials
ARG NAMESPACE=monsters
ARG TARGETARCH=amd64
ARG KUBECTL_VERSION=1.25.4
RUN dnf update -y && dnf install wget ca-certificates -y
RUN wget http://distro.ibiblio.org/pub/linux/distributions/slitaz/sources/packages/d/doom1.wad
RUN echo "TARGETARCH is $TARGETARCH"
RUN echo "KUBECTL_VERSION is $KUBECTL_VERSION"
RUN echo "NAMESPACE is $NAMESPACE"
RUN wget -O /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/$TARGETARCH/kubectl" \
  && chmod +x /usr/bin/kubectl

FROM fedora:37 AS build-doom
RUN dnf update -y && dnf groupinstall 'Development Tools' -y \
  && dnf install -y \
  sdl12-compat \
  SDL_mixer-devel \
  SDL_net-devel \ 
  gcc
ADD /dockerdoom /dockerdoom
WORKDIR /dockerdoom/trunk
RUN ./configure && make && make install

FROM fedora:37 as build-converge
WORKDIR /build
RUN mkdir -p \
  /build/root \
  /build/usr/bin \
  /build/usr/local/games
COPY --from=build-essentials /doom1.wad /build/root
COPY --from=build-essentials /usr/bin/kubectl /build/usr/bin
COPY --from=build-ocpdoom /go/src/ocpdoom/ocpdoom /build/usr/bin
COPY --from=build-doom /usr/local/games/psdoom /build/usr/local/games

FROM fedora:37
ARG VNCPASSWORD=openshift
RUN dnf update -y \
  && dnf install -y \
  sdl12-compat \
  SDL_mixer-devel \
  SDL_net-devel \
  xorg-x11-server-Xvfb \
  nmap \
  x11vnc \
  && dnf clean all -y
RUN mkdir /root/.vnc && x11vnc -storepasswd "${VNCPASSWORD}" /root/.vnc/passwd
COPY --from=build-converge /build /
WORKDIR /root
ENTRYPOINT ["/usr/bin/ocpdoom"]
