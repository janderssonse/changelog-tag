# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: CC0-1.0

# WORK IN PROGRESS, not supported yet really
FROM cgr.dev/chainguard/wolfi-base:latest

ENV DEFAULT_ARGS "--help"

RUN apk update && apk add --no-cache --update-cache \
  curl \
  acl \
  bash \
  git \
  libstdc++ \
  gpg \
  openssh-client \
  openssh-keygen \
  && ln -sf /bin/bash /bin/sh

SHELL ["/bin/bash", "-c"]

RUN mkdir -p /app/repo && git clone https://github.com/asdf-vm/asdf.git /app/.asdf --branch v0.11.2 \
  && echo '. /app/.asdf/asdf.sh' >> /etc/bash.bashrc

ENV ASDF_DIR=/app/.asdf
ENV ASDF_DATA_DIR=/app/.asdf

COPY /.tool-versions /app/.tool-versions
COPY /src/changelog_tag.sh /app/changelog_tag.sh
COPY /src/changelog_tag_templates /app/changelog_tag_templates

RUN export ASDF_DIR='/app/.asdf' && export ASDF_DATA_DIR='/app/.asdf' \
  && source '/app/.asdf/asdf.sh' && cut -d' ' -f1 /app/.tool-versions | xargs -i asdf plugin add {} \
  && cd /app && asdf install


CMD ["/bin/bash", "-c","source /etc/bash.bashrc;/app/changelog_tag.sh ${ARGS:-${DEFAULT_ARGS}}"]
