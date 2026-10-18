# Why `setup-deployment`'s steps are as they are

The reasons behind `setup-deployment`'s steps. The steps themselves are in [SKILL.md](../SKILL.md).

## Step 4: Containerise properly

Keep the image thin because every megabyte is pull latency on every deploy and every package is
attack surface.

Record the image size in the runbook so growth is visible.

## Step 5: Wire observability

A service with no telemetry is a service whose next incident is measured in hours.

The exporter is gated on the endpoint variable so local development stays quiet.

Instrument with OpenTelemetry whichever backend it is, so the vendor sits behind the exporter and
switching is configuration rather than a rewrite.

## Step 6: Environments and secrets

Environments do not share a host or credential unless recorded as a decision, because sharing means
one incident takes both.
