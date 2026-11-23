import '../models/api_models.dart';
import '../services/employer_api_service.dart';
import 'base_controller.dart';
import '../core/api/api_exception.dart';

class DashboardController extends BaseController {
  DashboardController(this.api);
  final EmployerApiService api;
  DashboardData? data;
  Future<void> load() async {
    data = await run(api.dashboard);
    notifyListeners();
  }

  void clear() {
    data = null;
    error = null;
    hasLoaded = false;
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
  Future<void> load() async {
    profile = await run(api.profile);
    notifyListeners();
  }

  Future<bool> save(Json values) async {
    // Keep the profile API from being reached with an invalid GSTIN even when
    // a caller outside the registration form saves the profile.
    final gstinError = _gstinProblem(values['gstin']);
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

  String? _gstinProblem(dynamic rawValue) {
    if (rawValue == null) return null;
    final gst = '$rawValue'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (gst.isEmpty) return null;
    if (gst.length != 15) {
      return 'A GST number has 15 characters, like 22ABCDE1234F1ZA.';
    }
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
    ).hasMatch(gst)) {
      return 'Enter the GST number in the format 22ABCDE1234F1ZA.';
    }
    final stateCode = int.parse(gst.substring(0, 2));
    if (!((stateCode >= 1 &&
            stateCode <= 38 &&
            stateCode != 25 &&
            stateCode != 28) ||
        stateCode == 97)) {
      return 'A GST number starts with a state code (01–38). Check the first two digits.';
    }
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var sum = 0;
    for (var index = 0; index < 14; index++) {
      final value = chars.indexOf(gst[index]) * (index.isEven ? 1 : 2);
      sum += value ~/ 36 + value % 36;
    }
    return gst[14] == chars[(36 - sum % 36) % 36]
        ? null
        : 'This GST number is not valid. Check it for a typing mistake.';
  }

  void clear() {
    profile = null;
    validationErrors = const {};
    error = null;
    hasLoaded = false;
    notifyListeners();
  }
}
