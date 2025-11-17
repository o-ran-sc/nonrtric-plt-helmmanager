#  ============LICENSE_START===============================================
#  Copyright (C) 2020-2023 Nordix Foundation. All rights reserved.
#  Copyright (C) 2023-2025 OpenInfra Foundation Europe. All rights reserved.
#  ========================================================================
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  ============LICENSE_END=================================================
#

FROM nexus3.o-ran-sc.org:10001/curlimages/curl:7.78.0 AS base-build

#Get helm
RUN wget -O /tmp/helm.tar.gz https://nexus.o-ran-sc.org/content/repositories/helm/helm-v3.6.1-linux-amd64.tar.gz

#Get kubectl
RUN wget -O /tmp/kubectl https://nexus.o-ran-sc.org/content/repositories/kubectl/v1.20.2/bin/linux/amd64/kubectl

#Get JDK & shrink it to equivalent to a JRE
FROM nexus3.o-ran-sc.org:10001/amazoncorretto:17.0.17 AS jre-build
RUN yum install -y binutils

RUN $JAVA_HOME/bin/jlink \
   --verbose \
   --add-modules ALL-MODULE-PATH \
   --strip-debug \
   --no-man-pages \
   --no-header-files \
   --compress=2 \
   --output /customjre

# Use debian base image
FROM nexus3.o-ran-sc.org:10001/debian:11-slim

#Install helm from base-build image
COPY --from=base-build /tmp/helm.tar.gz .
RUN tar -zxvf helm.tar.gz && \
   mv linux-amd64/helm /usr/local/bin/helm

#Install kubectl from base-build image
COPY --from=base-build /tmp/kubectl .
RUN chmod +x ./kubectl  && \
   mv ./kubectl /usr/local/bin/kubectl

#Copy JRE from the jre-base image
ENV JAVA_HOME=/jre
ENV PATH=${JAVA_HOME}/bin:${PATH}
COPY --from=jre-build /customjre $JAVA_HOME


WORKDIR /etc/app/helm-manager
COPY config/application.yaml .

WORKDIR /opt/app/helm-manager
COPY target/app.jar app.jar

ARG user=nonrtric
ARG group=nonrtric

RUN groupadd $group && \
   useradd -r -g $group $user && \
   chown -R $user:$group /opt/app/helm-manager && \
   chown -R $user:$group /etc/app/helm-manager

RUN mkdir /var/helm-manager-service && \
   chown -R $user:$group /var/helm-manager-service

RUN mkdir /home/$user && \
   chown -R $user:$group /home/$user

USER $user

CMD [ "java", "-jar", "app.jar", "--spring.config.location=optional:file:/etc/app/helm-manager/"]
