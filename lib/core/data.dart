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
  });

  final String name;
  final String trade;
  final String status;
  final int experience;
  final int wage;
  final double rating;
  final double distance;
  final List<String> skills;

  String get initials => name.split(' ').map((e) => e[0]).take(2).join();
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
