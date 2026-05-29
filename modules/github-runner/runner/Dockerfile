FROM public.ecr.aws/ubuntu/ubuntu:22.04

ARG RUNNER_VERSION=2.319.1
ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq sudo unzip libicu70 \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m runner \
 && mkdir -p /actions-runner \
 && chown runner:runner /actions-runner

USER runner
WORKDIR /actions-runner

RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64") \
 && curl -fsSL -o runner.tar.gz \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz" \
 && tar xzf runner.tar.gz \
 && rm runner.tar.gz

COPY --chown=runner:runner entrypoint.sh /actions-runner/entrypoint.sh

ENTRYPOINT ["/actions-runner/entrypoint.sh"]
