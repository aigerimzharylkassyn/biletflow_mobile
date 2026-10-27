import 'event.dart';

enum TicketStatus { upcoming, past }

class AppTicket {
  final String id;
  final bool canRequestRefund;
  final String admissionStatus;
  final String? orderId;
  final String? ticketTypeId;
  final String? seat;
  final String? section;
  final String? row;
  final AppEvent event;
  final String ticketCode;
  final TicketStatus status;
  final String holderName;

  const AppTicket({
    required this.id,
    this.canRequestRefund = false,
    this.admissionStatus = 'valid',
    this.orderId,
    this.ticketTypeId,
    this.seat,
    this.section,
    this.row,
    required this.event,
    required this.ticketCode,
    required this.status,
    required this.holderName,
  });
  bool get canShowQr =>
      event.eventStatus != 'cancelled' &&
      (admissionStatus == 'valid' || admissionStatus == 'checked_in');
}
