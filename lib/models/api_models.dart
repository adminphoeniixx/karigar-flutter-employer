typedef Json = Map<String, dynamic>;

int asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
List<String> asStrings(dynamic value) =>
    value is List ? value.map((e) => '$e').toList() : const [];

class Rating {
  const Rating({this.average = 0, this.count = 0});
  factory Rating.fromJson(dynamic value) {
    final json = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return Rating(
      average: asDouble(json['average']),
      count: asInt(json['count']),
    );
  }
  final double average;
  final int count;
}

class EmployerProfile {
  const EmployerProfile({
    required this.id,
    required this.name,
    required this.companyName,
    this.hiringAs,
    this.industry,
    this.companySize,
    this.hiringCategories = const [],
    this.gstin,
    this.phone,
    this.about,
    this.address,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.verified = false,
    this.completion = 0,
    this.rating = const Rating(),
  });
  factory EmployerProfile.fromJson(Json json) => EmployerProfile(
    id: asInt(json['id']),
    name: '${json['name'] ?? ''}',
    companyName: '${json['company_name'] ?? ''}',
    hiringAs: json['hiring_as']?.toString(),
    industry: json['industry']?.toString(),
    companySize: json['company_size']?.toString(),
    hiringCategories: asStrings(json['hiring_categories']),
    gstin: json['gstin']?.toString(),
    phone: json['phone']?.toString(),
    about: json['about']?.toString(),
    address: json['address']?.toString(),
    city: json['city']?.toString(),
    state: json['state']?.toString(),
    latitude: json['latitude'] == null ? null : asDouble(json['latitude']),
    longitude: json['longitude'] == null ? null : asDouble(json['longitude']),
    logoUrl: json['logo_url']?.toString(),
    verified: json['verified'] == true,
    completion: asInt(json['completion']),
    rating: Rating.fromJson(json['rating']),
  );
  final int id;
  final String name;
  final String companyName;
  final String? hiringAs,
      industry,
      companySize,
      gstin,
      phone,
      about,
      address,
      city,
      state,
      logoUrl;
  final double? latitude, longitude;
  final List<String> hiringCategories;
  final bool verified;
  final int completion;
  final Rating rating;
}

class CreditSummary {
  const CreditSummary({
    this.balance = 0,
    this.purchased = 0,
    this.planRemaining = 0,
    this.unmetered = false,
    this.planLabel = '',
  });
  factory CreditSummary.fromJson(dynamic value) {
    final json = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return CreditSummary(
      balance: asInt(json['balance']),
      purchased: asInt(json['purchased']),
      planRemaining: asInt(json['plan_remaining']),
      unmetered: json['unmetered'] == true,
      planLabel: '${json['plan_label'] ?? ''}',
    );
  }
  final int balance, purchased, planRemaining;
  final bool unmetered;
  final String planLabel;
}

class EmployerJob {
  const EmployerJob({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.wageLabel,
    this.description = '',
    this.skills = const [],
    this.locationLabel = '',
    this.vacancies = 0,
    this.stats = const {},
  });
  factory EmployerJob.fromJson(Json json) => EmployerJob(
    id: asInt(json['id']),
    title: '${json['title'] ?? ''}',
    category: '${json['category'] ?? ''}',
    status: '${json['status'] ?? ''}',
    wageLabel: '${json['wage_label'] ?? ''}',
    description: '${json['description'] ?? ''}',
    skills: asStrings(json['skills']),
    locationLabel: '${json['location_label'] ?? ''}',
    vacancies: asInt(json['vacancies']),
    stats: json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'])
        : const {},
  );
  final int id, vacancies;
  final String title, category, status, wageLabel, description, locationLabel;
  final List<String> skills;
  final Json stats;
}

class WorkerProfile {
  const WorkerProfile({
    required this.id,
    required this.name,
    this.userId = 0,
    this.bio = '',
    this.skills = const [],
    this.languages = const [],
    this.city = '',
    this.state = '',
    this.experienceYears = 0,
    this.expectedWage = 0,
    this.wageType = 'daily',
    this.available = false,
    this.verified = false,
    this.locked = true,
    this.phone,
    this.email,
    this.distanceKm,
    this.rating = const Rating(),
  });
  factory WorkerProfile.fromJson(Json json) => WorkerProfile(
    id: asInt(json['id']),
    userId: asInt(json['user_id']),
    name: '${json['name'] ?? ''}',
    bio: '${json['bio'] ?? ''}',
    skills: asStrings(json['skills']),
    languages: asStrings(json['spoken_languages']),
    city: '${json['city'] ?? ''}',
    state: '${json['state'] ?? ''}',
    experienceYears: asInt(json['experience_years']),
    expectedWage: asInt(json['expected_wage']),
    wageType: '${json['wage_type'] ?? 'daily'}',
    available: json['available'] == true,
    verified: json['verified'] == true,
    locked: json['locked'] == true || json['contact_unlocked'] == false,
    phone: json['phone']?.toString(),
    email: json['email']?.toString(),
    distanceKm: json['distance_km'] == null
        ? null
        : asDouble(json['distance_km']),
    rating: Rating.fromJson(json['rating']),
  );
  final int id, userId, experienceYears, expectedWage;
  final String name, bio, city, state, wageType;
  final String? phone, email;
  final List<String> skills, languages;
  final bool available, verified, locked;
  final double? distanceKm;
  final Rating rating;
}

class Applicant {
  const Applicant({
    required this.id,
    required this.stage,
    required this.worker,
    this.shortlisted = false,
    this.contactUnlocked = false,
  });
  factory Applicant.fromJson(Json json) => Applicant(
    id: asInt(json['id']),
    stage: '${json['stage'] ?? 'pending'}',
    shortlisted: json['shortlisted'] == true,
    contactUnlocked: json['contact_unlocked'] == true,
    worker: WorkerProfile.fromJson(
      Map<String, dynamic>.from(json['worker'] as Map? ?? {}),
    ),
  );
  final int id;
  final String stage;
  final bool shortlisted, contactUnlocked;
  final WorkerProfile worker;
}

class DashboardData {
  const DashboardData({
    required this.greeting,
    required this.stats,
    required this.credits,
    required this.jobs,
    required this.applicants,
    this.profile,
  });
  factory DashboardData.fromJson(Json json) => DashboardData(
    greeting: '${json['greeting'] ?? ''}',
    stats: json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'])
        : const {},
    credits: CreditSummary.fromJson(json['credits']),
    jobs: (json['active_jobs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => EmployerJob.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    applicants: (json['recent_applicants'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Applicant.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    profile: json['profile'] is Map
        ? EmployerProfile.fromJson(Map<String, dynamic>.from(json['profile']))
        : null,
  );
  final String greeting;
  final Json stats;
  final CreditSummary credits;
  final List<EmployerJob> jobs;
  final List<Applicant> applicants;
  final EmployerProfile? profile;
}
