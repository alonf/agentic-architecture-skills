# A clean machine for the install verification (SC-001): nothing on it but Node, git and the two hosts
# at pinned versions, and a fresh non-root user whose home has never seen either host. The package is
# NOT copied in - the test installs it the way the README says to, from GitHub, so a passing run means
# the published path works, not that a local copy does.
#
# Every version here is exact. The base image is a specific Node release, the hosts are specific npm
# versions, and the README's "Development tooling" section lists the same numbers.

ARG NODE_IMAGE=node:22.23.2-bookworm-slim
FROM ${NODE_IMAGE}

ARG CLAUDE_CODE_VERSION=2.1.267
ARG COPILOT_CLI_VERSION=1.0.83
ARG SKILLS_CLI_VERSION=1.5.25

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN npm install --global --no-fund --no-audit \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      "@github/copilot@${COPILOT_CLI_VERSION}" \
      "skills@${SKILLS_CLI_VERSION}" \
 && npm cache clean --force

# The hosts' user-level state lives under HOME. A dedicated user guarantees that state starts empty.
RUN useradd --create-home --shell /bin/bash tester
USER tester
WORKDIR /home/tester

COPY --chown=tester:tester run-install.sh /usr/local/bin/run-install.sh
ENTRYPOINT ["bash", "/usr/local/bin/run-install.sh"]
