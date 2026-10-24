// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_calcom/otel_calcom.dart';

/// Traces Cal.com v2 calls with OpenTelemetry.
///
/// `otel_calcom` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Cal.com v2 call in
/// [tracedCalcom]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'calcom-example');

  // Wraps a Cal.com v2 API call in a CLIENT span.
  final calcomId = await tracedCalcom<String>(
    operation: 'bookings.create',
    apiVersion: '1',
    invoke: () async {
      // Make the Cal.com v2 call here, then report what it returned.
      const id = 'calcom_8f3a2c';
      return const CalcomCallResult(
          value: id,
          result: CalcomResult(
              itemCount: 3,
              slotsReturned: 1,
              eventTypeId: 1,
              bookingId: 1,
              bookingStatus: 'pending',
              schedulingType: 'roundRobin',
              deployment: 'cloud',
              rescheduledFrom: 1,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedCalcom bookings.create returned $calcomId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutCalcomInstrumentationAsync.
  await runWithoutCalcomInstrumentationAsync(
    () => tracedCalcom<String>(
      operation: 'bookings.create',
      apiVersion: '1',
      invoke: () async {
        const id = 'calcom_8f3a2c';
        return const CalcomCallResult(
            value: id,
            result: CalcomResult(
                itemCount: 3,
                slotsReturned: 1,
                eventTypeId: 1,
                bookingId: 1,
                bookingStatus: 'pending',
                schedulingType: 'roundRobin',
                deployment: 'cloud',
                rescheduledFrom: 1,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
