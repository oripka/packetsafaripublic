FROM ubuntu:latest AS wireshark-tools-base-build
RUN sed -i -e 's/http:\/\/archive\.ubuntu\.com\/ubuntu\//http:\/\/ftp.udc.es\/ubuntu\//' /etc/apt/sources.list
RUN sed -i -e 's/http:\/\/security\.ubuntu\.com\/ubuntu\//http:\/\/ftp.udc.es\/ubuntu\//' /etc/apt/sources.list
RUN apt-get update && DEBIAN_FRONTEND="noninteractive" apt-get install -y wget git libc-ares-dev libc-dev libglib2.0-dev libgcrypt-dev cmake bison flex gdb gdbserver netcat libpcap-dev libgnutls28-dev libsmi2-dev libmaxminddb-dev liblua5.3-dev build-essential
RUN mkdir /src
WORKDIR /src
RUN git clone https://github.com/oripka/wireshark.git
WORKDIR /src/wireshark
RUN git fetch
RUN git checkout waveanalyzer-3.6.2
RUN mkdir build
WORKDIR build
RUN cmake -DBUILD_wireshark=OFF -DBUILD_tshark=ON -DBUILD_dumpcap=OFF -DBUILD_androiddump=OFF ../
# RUN cmake -DCMAKE_BUILD_TYPE=Debug -DBUILD_wireshark=OFF -DBUILD_tshark=ON -DBUILD_dumpcap=OFF -DBUILD_androiddump=OFF ../
RUN make -j 9
WORKDIR /src/wireshark/build

### WIRESHARK TOOLS BUILDER
###
# quicker build of updated wireshark tools
# docker build --target wireshark-tools-builder -f .\Dockerfile.buildimage .
FROM wireshark-tools-base-build AS wireshark-tools-builder
ADD https://api.github.com/repos/oripka/wireshark/git/refs/heads/waveanalyzer-3.6.2 version.json
RUN git pull
RUN make -j 9
RUN rm -rf wireshark
RUN mkdir wireshark
RUN cp -a run/* wireshark
RUN tar cvf wireshark.tar wireshark
# Copy over some default pcaps, useful for testing
RUN mkdir /pcaps
COPY ./wave-backend/waveanalyzer/rsrc/pcaps/*.pcapng /pcaps/
COPY ./wave-backend/waveanalyzer/rsrc/pcaps/*.pcap /pcaps/

### WIRESHARK TOOLS PRODUCTION
###
# copy built binaries over and put it into a minimal base image
FROM ubuntu:latest AS wireshark-tools-production
RUN sed -i -e 's/http:\/\/archive\.ubuntu\.com\/ubuntu\//http:\/\/ftp.udc.es\/ubuntu\//' /etc/apt/sources.list
RUN sed -i -e 's/http:\/\/security\.ubuntu\.com\/ubuntu\//http:\/\/ftp.udc.es\/ubuntu\//' /etc/apt/sources.list
RUN apt-get update && apt-get install -y libglib2.0-0 libpcap0.8 libsmi2ldbl libc-ares2 libmaxminddb0
# START WIRESHARK TOOLING
WORKDIR /
COPY --from=wireshark-tools-builder /src/wireshark/build/wireshark.tar /
COPY ./wave-backend/GeoIP /var/lib/GeoIP
RUN tar xvf wireshark.tar
RUN rm wireshark.tar
COPY ./wave-backend/default_colorrules_wireshark /src/wireshark/default_colorrules_wireshark
WORKDIR wireshark
RUN cp /wireshark/lib* /usr/lib
RUN cp /wireshark/tshark /usr/bin
RUN cp /wireshark/sharkd /usr/bin
RUN cp /wireshark/editcap /usr/bin
RUN cp /wireshark/capinfos /usr/bin
RUN cp /wireshark/mmdbresolve /usr/bin
RUN mkdir /usr/local/share/wireshark 
WORKDIR /usr/local/share/wireshark/
RUN ln -s /wireshark/manuf
RUN ln -s /wireshark/services
WORKDIR /wireshark
