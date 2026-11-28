class Job {
  const Job(
    this.title,
    this.category,
    this.wage,
    this.openings,
    this.applied,
    this.shortlisted,
    this.hired,
    this.status, {
    this.id = 0,
    this.views = 0,
    this.moderationNote,
    this.moderationStatus,
    this.moderationMethod,
    this.workModeLabel,
    this.interviewModeLabel,
  });

  final String title;
  final String category;
  final String wage;
  final String status;
  final int openings;
  final int applied;
  final int shortlisted;
  final int hired;
  final int id;

  /// How many times karigars opened the job (the API's `stats.views`).
  final int views;
  final String? moderationNote;
  final String? moderationStatus, moderationMethod;
  final String? workModeLabel, interviewModeLabel;
}

class Worker {
  const Worker(
    this.name,
    this.trade,
    this.experience,
    this.rating,
    this.distance,
    this.wage,
    this.skills, {
    this.status = 'Pending',
    this.verified = false,
  });

  final String name;
  final String trade;
  final String status;
  final bool verified;
  final int experience;
  final int wage;
  final double rating;
  final double distance;
  final List<String> skills;

  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join()
      .toUpperCase();
}

/// Indian digit grouping: 1178 → "1,178", 150000 → "1,50,000".
String indianDigits(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  if (digits.length <= 3) return '${negative ? '-' : ''}$digits';
  final tail = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (head.length > 2) {
    groups.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) groups.insert(0, head);
  return '${negative ? '-' : ''}${groups.join(',')},$tail';
}

String monthlyWage(num? amount) {
  if (amount == null || amount <= 0) return '—';
  return '₹${indianDigits(amount.round())}/month';
}

const jobs = [
  Job(
    'Plumber for Apartment Project',
    'Plumbing',
    '\u20B9800\u20131000 / day',
    3,
    12,
    3,
    1,
    'Active',
  ),
  Job(
    'Electrician \u2014 House Wiring',
    'Electrical',
    '\u20B9900\u20131200 / day',
    2,
    8,
    2,
    0,
    'Active',
  ),
  Job(
    'Interior wall painting',
    'Painting',
    '\u20B9700\u2013900 / day',
    6,
    0,
    0,
    0,
    'Draft',
  ),
];

const workers = [
  Worker('Ramesh Kumar', 'Plumber', 7, 4.8, 2.4, 900, [
    'Pipe fitting',
    'Bathroom',
    'Leak repair',
  ]),
  Worker('Suresh Yadav', 'Electrician', 5, 4.7, 3.1, 950, [
    'Wiring',
    'MCB',
    'Maintenance',
  ], status: 'Shortlisted'),
  Worker('Arjun Singh', 'Plumber', 9, 4.9, 4.6, 1100, [
    'Commercial',
    'Pipeline',
    'Sanitary',
  ]),
  Worker('Imran Khan', 'Painter', 6, 4.6, 5.2, 800, [
    'Texture',
    'Polish',
    'Exterior',
  ]),
];
