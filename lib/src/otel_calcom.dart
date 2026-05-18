// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_calcom_suppression.dart';

const _tracerName = 'dartastic_otel_libs_calcom';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class CalcomResult {
  const CalcomResult({
    this.itemCount,
    this.slotsReturned,
    this.eventTypeId,
    this.bookingId,
    this.bookingStatus,
    this.schedulingType,
    this.deployment,
    this.rescheduledFrom,
    this.requestId,
    this.statusCode,
  });

  /// `data.length` for list endpoints.
  final int? itemCount;

  /// Available time slots returned by `/slots`.
  final int? slotsReturned;

  /// Cal.com `eventTypeId`.
  final int? eventTypeId;

  /// Booking id.
  final int? bookingId;

  /// `pending` / `accepted` / `cancelled` / `rejected`.
  final String? bookingStatus;

  /// `roundRobin` / `collective` / `managed` (team event scheduling).
  final String? schedulingType;

  /// `cloud` / `self_hosted` — cost/SLA dim, since Cal.com Cloud has
  /// per-booking limits while self-hosted does not.
  final String? deployment;

  /// Source booking id when this is a reschedule.
  final int? rescheduledFrom;

  /// `x-request-id`.
  final String? requestId;

  final int? statusCode;
}

class CalcomCallResult<T> {
  const CalcomCallResult({required this.value, this.result});
  final T value;
  final CalcomResult? result;
}

/// Wraps a Cal.com v2 API call in a CLIENT span. [operation] is one of
/// `bookings.list`, `bookings.create`, `bookings.cancel`,
/// `bookings.reschedule`, `bookings.get`, `event_types.list`,
/// `event_types.create`, `event_types.update`, `slots.available`,
/// `schedules.list`, `users.me`, `webhooks.create`, `teams.list`,
/// `org_memberships.list`.
Future<T> tracedCalcom<T>({
  required String operation,
  required Future<CalcomCallResult<T>> Function() invoke,
  String? apiVersion,
}) async {
  if (calcomInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'calcom',
    'rpc.method': operation,
    'calcom.operation': operation,
  };
  if (apiVersion != null) m['calcom.api_version'] = apiVersion;

  final span = _tracer().startSpan(
    'calcom $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'calcom.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.slotsReturned != null) {
        extras.add(OTel.attributeInt(
          'calcom.slots_returned',
          r.result!.slotsReturned!,
        ));
      }
      if (r.result!.eventTypeId != null) {
        extras.add(OTel.attributeInt(
          'calcom.event_type.id',
          r.result!.eventTypeId!,
        ));
      }
      if (r.result!.bookingId != null) {
        extras.add(OTel.attributeInt(
          'calcom.booking.id',
          r.result!.bookingId!,
        ));
      }
      if (r.result!.bookingStatus != null) {
        extras.add(OTel.attributeString(
          'calcom.booking.status',
          r.result!.bookingStatus!,
        ));
        if (r.result!.bookingStatus == 'rejected') {
          span.setStatus(
            SpanStatusCode.Error,
            'Cal.com booking rejected',
          );
        }
      }
      if (r.result!.schedulingType != null) {
        extras.add(OTel.attributeString(
          'calcom.scheduling.type',
          r.result!.schedulingType!,
        ));
      }
      if (r.result!.deployment != null) {
        extras.add(OTel.attributeString(
          'calcom.deployment',
          r.result!.deployment!,
        ));
      }
      if (r.result!.rescheduledFrom != null) {
        extras.add(OTel.attributeInt(
          'calcom.booking.rescheduled_from',
          r.result!.rescheduledFrom!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'calcom.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Cal.com HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
