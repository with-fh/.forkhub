# Measure daily use of the ForkHub Linux desktop build

Mirror T3 Code's product telemetry controls in the ForkHub Linux build.
Reporting is on by default for packaged releases from the with-fh
catalog. Read login-shell preferences before sending. Honor
FORKHUB_TELEMETRY_ENABLED=false and DO_NOT_TRACK=1. The latter takes
precedence. Disable by default in CI.

Count one foreground workspace use per UTC day. Create a random local
installation seed and send only its SHA-256 pseudonym and the ForkHub
build version to the first-party collector. Do not emit events on
background update checks, welcome windows, or dev builds. Never include
project data, account IDs, prompt content, or machine identifiers.

Use a best-effort request at workspace focus or foreground input. Failed
requests never interrupt the workspace. The collector deduplicates
retries across app restarts. Upstream DeepSeek telemetry is independent.
