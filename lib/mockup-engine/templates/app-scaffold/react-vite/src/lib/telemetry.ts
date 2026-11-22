/**
 * Browser telemetry over OpenTelemetry (Keel observability: OTLP to SigNoz by default, never a
 * vendor SDK in application code).
 *
 * Off unless VITE_OTEL_EXPORTER_OTLP_ENDPOINT is set, so local development sends nothing and pays
 * nothing: the SDK is loaded with a dynamic import only when enabled.
 */
import type { Logger } from '@opentelemetry/api';

// The service name every span and log carries: rename it to the app's (`<app>-web`).
const SERVICE = 'app-web';
const ENDPOINT = import.meta.env.VITE_OTEL_EXPORTER_OTLP_ENDPOINT as string | undefined;
const ENV = (import.meta.env.VITE_APP_ENV as string | undefined) ?? import.meta.env.MODE;

let logger: Logger | undefined;
let actor: string | undefined;

/** Redacts values that must never leave the browser: query strings, phone numbers, long digit runs, tokens. */
export function redact(text: string): string {
  return text
    .replace(/(https?:\/\/[^\s?#]+|\/[\w/.-]*)\?[^\s#]*/g, '$1?[redacted]')
    .replace(/\b(bearer|token|key|secret)[=:\s]+[\w.-]+/gi, '$1=[redacted]')
    .replace(/\d{7,}/g, (d) => `[digits:${d.slice(-4)}]`);
}

/** Starts tracing and error logs when an endpoint is configured. Safe to call once at startup. */
export async function initTelemetry(): Promise<void> {
  if (!ENDPOINT) return;
  const [
    { trace, context, propagation },
    { W3CTraceContextPropagator },
    { TracerProvider, BatchSpanProcessor, StackContextManager },
    { OTLPTraceExporter },
    { resourceFromAttributes },
    { registerInstrumentations },
    { FetchInstrumentation },
    { LoggerProvider, BatchLogRecordProcessor },
    { OTLPLogExporter },
  ] = await Promise.all([
    import('@opentelemetry/api'),
    import('@opentelemetry/core'),
    import('@opentelemetry/sdk-trace'),
    import('@opentelemetry/exporter-trace-otlp-http'),
    import('@opentelemetry/resources'),
    import('@opentelemetry/instrumentation'),
    import('@opentelemetry/instrumentation-fetch'),
    import('@opentelemetry/sdk-logs'),
    import('@opentelemetry/exporter-logs-otlp-http'),
  ]);
  const resource = resourceFromAttributes({ 'service.name': SERVICE, 'deployment.environment.name': ENV });
  // OpenTelemetry 3.x has no WebTracerProvider: the provider, the browser's context manager and the
  // W3C propagator are registered one by one.
  const tracer = new TracerProvider({
    resource,
    spanProcessors: [new BatchSpanProcessor({ exporter: new OTLPTraceExporter({ url: `${ENDPOINT}/v1/traces` }) })],
  });
  trace.setGlobalTracerProvider(tracer);
  context.setGlobalContextManager(new StackContextManager().enable());
  propagation.setGlobalPropagator(new W3CTraceContextPropagator());
  registerInstrumentations({
    instrumentations: [
      new FetchInstrumentation({
        // traceparent goes to our own API only, so a browser error joins the backend trace
        propagateTraceHeaderCorsUrls: [new RegExp(`^${window.location.origin}`)],
        ignoreUrls: [new RegExp(ENDPOINT)],
        // Query strings carry filters and identifiers: strip them from every URL attribute.
        applyCustomAttributesOnSpan: (span) => {
          const attrs = (span as unknown as { attributes?: Record<string, unknown> }).attributes ?? {};
          for (const key of ['http.url', 'url.full']) {
            const value = attrs[key];
            if (typeof value === 'string') span.setAttribute(key, redact(value));
          }
        },
      }),
    ],
  });
  const logs = new LoggerProvider({
    resource,
    processors: [new BatchLogRecordProcessor({ exporter: new OTLPLogExporter({ url: `${ENDPOINT}/v1/logs` }) })],
  });
  logger = logs.getLogger(SERVICE);

  window.addEventListener('error', (e) => reportError(e.error ?? e.message, { op: 'window.error' }));
  window.addEventListener('unhandledrejection', (e) => reportError(e.reason, { op: 'window.unhandledrejection' }));
  window.addEventListener('pagehide', () => {
    void tracer.forceFlush();
    void logs.forceFlush();
  });
}

/** Who caused the error: the user id, never a name, phone number or email. */
export function setActor(userId: string | undefined): void {
  actor = userId;
}

export interface ErrorContext {
  /** The failing operation, a short stable string such as `session.read`. */
  op: string;
  /** Which keel skill to start with when this is pasted into an agent. */
  remediation?: string;
  [attribute: string]: string | number | undefined;
}

/** Reports an error once, at the boundary that handled it. Never log and rethrow. */
export function reportError(error: unknown, context: ErrorContext): void {
  const err = error instanceof Error ? error : new Error(String(error));
  const { op, remediation = `use keel:debug on op=${op}; root cause before any fix`, ...rest } = context;
  const attributes: Record<string, string | number> = {
    op,
    remediation,
    'exception.type': err.name,
    'exception.message': redact(err.message),
    'exception.stacktrace': redact(err.stack ?? ''),
    'url.path': window.location.pathname,
  };
  if (actor) attributes.actor = actor;
  for (const [k, v] of Object.entries(rest)) if (v !== undefined) attributes[k] = typeof v === 'string' ? redact(v) : v;

  if (!logger) {
    if (import.meta.env.DEV) console.error(`[${op}]`, err);
    return;
  }
  // SeverityNumber.ERROR is 17; inlined so the logs runtime stays out of the main bundle.
  logger.emit({ severityNumber: 17, severityText: 'ERROR', body: `${op} failed: ${redact(err.message)}`, attributes });
}
