import '../models/api_models.dart';
import '../services/employer_api_service.dart';
import 'base_controller.dart';

class DashboardController extends BaseController {
  DashboardController(this.api);
  final EmployerApiService api;
  DashboardData? data;
  Future<void> load() async {
    data = await run(api.dashboard);
    notifyListeners();
  }
}

class JobsController extends BaseController {
  JobsController(this.api);
  final EmployerApiService api;
  List<EmployerJob> items = [];
  String status = 'active';

  Future<void> load({String? nextStatus}) async {
    status = nextStatus ?? status;
    final result = await run(() => api.jobs(status: status));
    if (result != null) items = result;
    notifyListeners();
  }

  Future<bool> create(Json values) async {
    final result = await run(() => api.createJob(values));
    if (result == null) return false;
    items.insert(0, result);
    notifyListeners();
    return true;
  }
}

class WorkersController extends BaseController {
  WorkersController(this.api);
  final EmployerApiService api;
  List<WorkerProfile> items = [];
  Json access = {};
  Json contactCounts = {};
  int total = 0;
  int page = 1;
  int lastPage = 1;
  Map<String, dynamic> _filters = {};

  bool get hasMore => page < lastPage;

  /// Starts a new directory search from the first server page.
  Future<void> search([Map<String, dynamic> filters = const {}]) =>
      _fetch(filters, more: false);

  /// Appends the next server page to the current directory results.
  Future<void> loadMore() => _fetch(_filters, more: true);

  Future<void> _fetch(
    Map<String, dynamic> filters, {
    required bool more,
  }) async {
    if (loading || (more && !hasMore)) return;
    final nextPage = more ? page + 1 : 1;
    final activeFilters = more ? _filters : Map<String, dynamic>.from(filters);
    final response = await run(
      () => api.workers({...activeFilters, 'page': nextPage}),
    );
    if (response == null) return;
    contactCounts = response['contact_counts'] is Map
        ? Json.from(response['contact_counts'])
        : {};
    final wrapper = response['workers'];
    total = wrapper is Map ? asInt(wrapper['total']) : 0;
    final rows = wrapper is Map ? wrapper['data'] as List? : null;
    final incoming = (rows ?? const [])
        .whereType<Map>()
        .map((e) => WorkerProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    items = more ? [...items, ...incoming] : incoming;
    page = wrapper is Map && asInt(wrapper['current_page']) > 0
        ? asInt(wrapper['current_page'])
        : nextPage;
    lastPage = wrapper is Map && asInt(wrapper['last_page']) > 0
        ? asInt(wrapper['last_page'])
        : page;
    _filters = Map<String, dynamic>.from(activeFilters);
    access = response['access'] is Map
        ? Map<String, dynamic>.from(response['access'])
        : {};
    notifyListeners();
  }
}

class ProfileController extends BaseController {
  ProfileController(this.api);
  final EmployerApiService api;
  EmployerProfile? profile;
  Future<void> load() async {
    profile = await run(api.profile);
    notifyListeners();
  }

  Future<bool> save(Json values) async {
    final value = await run(() => api.updateProfile(values));
    if (value == null) return false;
    profile = value;
    notifyListeners();
    return true;
  }
}
