/// Represents the attendance type of the individual checking in.
enum CheckInType {
  member('Member'),
  substitute('Substitute'),
  visitor('Visitor'),
  absent('Absent'),
  notCheckedIn('Not Checked In');

  const CheckInType(this.displayName);
  final String displayName;

  bool get isMember => this == CheckInType.member;
  bool get isSubstitute => this == CheckInType.substitute;
  bool get isVisitor => this == CheckInType.visitor;
  bool get isAbsent => this == CheckInType.absent;
  bool get isNotCheckedIn => this == CheckInType.notCheckedIn;
}
