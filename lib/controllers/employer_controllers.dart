import 'package:shared_preferences/shared_preferences.dart';
import 'package:employer_kariger_app/core/gstin.dart';

import '../models/api_models.dart';
import '../services/employer_api_service.dart';
import 'base_controller.dart';
import '../core/api/api_exception.dart';

class DashboardController extends BaseController {
  DashboardController(this.api);
  final EmployerApiService api;
  DashboardData? data;

  /// The business name from the last dashboard that loaded, kept on the
  /// phone so the header can greet the employer by name while offline.
  String? savedGreeting;
  static const _greetingKey = 'employer_dashboard_greeting';

  /// A failed refresh keeps the last dashboard on screen and sets [error].
  Future<void> load() async {
    final result = await run(api.dashboard);
    if (result != null) {
      data = result;
      if (result.greeting.isNotEmpty) await _saveGreeting(result.greeting);
    } else if (savedGreeting == null) {
      await _readGreeting();
    }
    notifyListeners();
  }

  Future<void> _saveGreeting(String greeting) async {
    savedGreeting = greeting;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _greetingKey,
        greeting,
      );
    } catch (_) {}
  }

  Future<void> _readGreeting() async {
    try {
      savedGreeting = (await SharedPreferences.getInstance()).getString(
        _greetingKey,
      );
    } catch (_) {}
  }

  /// On sign-out: the next account must not be greeted with this name.
  void clear() {
    data = null;
    savedGreeting = null;
    error = null;
    hasLoaded = false;
    SharedPreferences.getInstance()
        .then((preferences) => preferences.remove(_greetingKey))
        .catchError((_) => false);
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

  /// Removes a job that was closed while this list is open. The API can take a
  /// moment to reflect a status change in its filtered results, so keeping the
  /// local active list in sync prevents the closed job from lingering here.
  void markClosed(int jobId) {
    items = items.where((job) => job.id != jobId).toList();
    notifyListeners();
  }

  void clear() {
    items = [];
    status = 'active';
    error = null;
    hasLoaded = false;
    notifyListeners();
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

  void clear() {
    items = [];
    access = {};
    contactCounts = {};
    total = 0;
    page = 1;
    lastPage = 1;
    _filters = {};
    error = null;
    hasLoaded = false;
    notifyListeners();
  }
}

class ProfileController extends BaseController {
  ProfileController(this.api);
  final EmployerApiService api;
  EmployerProfile? profile;
  Map<String, dynamic> validationErrors = const {};

  /// A failed refresh keeps the last profile on screen and sets [error].
  Future<void> load() async {
    final result = await run(api.profile);
    if (result != null) profile = result;
    notifyListeners();
  }

  Future<bool> save(Json values) async {
    // Keep the profile API from being reached with an invalid GSTIN even when
    // a caller outside the registration form saves the profile.
    final gstinError = gstinProblem(values['gstin']?.toString());
    if (gstinError != null) {
      error = gstinError;
      validationErrors = {
        'gstin': [gstinError],
      };
      notifyListeners();
      return false;
    }
    loading = true;
    error = null;
    validationErrors = const {};
    notifyListeners();
    try {
      profile = await api.updateProfile(values);
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      validationErrors = exception.errors ?? const {};
      return false;
    } catch (_) {
      error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      loading = false;
      hasLoaded = true;
      notifyListeners();
    }
  }

  void clear() {
    profile = null;
    validationErrors = const {};
    error = null;
    hasLoaded = false;
    notifyListeners();
  }
}
