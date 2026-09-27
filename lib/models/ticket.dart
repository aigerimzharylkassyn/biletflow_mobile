import 'event.dart';

enum TicketStatus { upcoming, past }

class AppTicket {
  final String id;
  final AppEvent event;
  final String ticketCode;
  final TicketStatus status;
  final String holderName;

  const AppTicket({
    required this.id,
    required this.event,
    required this.ticketCode,
    required this.status,
    required this.holderName,
  });
}
