// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_calcom/otel_calcom.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_calcom-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('bookings.create records scheduling.type + deployment', () async {
    await tracedCalcom<String>(
      operation: 'bookings.create',
      apiVersion: '2024-08-13',
      invoke: () async => const CalcomCallResult(
        value: 'ok',
        result: CalcomResult(
          bookingId: 1001,
          bookingStatus: 'accepted',
          eventTypeId: 42,
          schedulingType: 'roundRobin',
          deployment: 'self_hosted',
          statusCode: 201,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('calcom bookings.create')!);
    expect(a['calcom.api_version'], '2024-08-13');
    expect(a['calcom.booking.id'], 1001);
    expect(a['calcom.scheduling.type'], 'roundRobin');
    expect(a['calcom.deployment'], 'self_hosted');
  });

  test('rejected booking sets span error', () async {
    await tracedCalcom<String>(
      operation: 'bookings.create',
      invoke: () async => const CalcomCallResult(
        value: 'ok',
        result: CalcomResult(bookingStatus: 'rejected'),
      ),
    );
    expect(
      spans.findSpanByName('calcom bookings.create')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutCalcomInstrumentationAsync(() async {
      await tracedCalcom<String>(
        operation: 'slots.available',
        invoke: () async => const CalcomCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('calcom '), isEmpty);
  });
}
