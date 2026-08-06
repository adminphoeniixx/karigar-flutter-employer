import '../models/api_models.dart';
import '../services/employer_api_service.dart';
import 'base_controller.dart';

class DashboardController extends BaseController {
  DashboardController(this.api);
  final EmployerApiService api;
  DashboardData? data;
  Future<void> load() async => data = await run(api.dashboard);
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

  Future<void> search([Map<String, dynamic> filters = const {}]) async {
    final response = await run(() => api.workers(filters));
    if (response == null) return;
    final wrapper = response['workers'];
    final rows = wrapper is Map ? wrapper['data'] as List? : null;
    items = (rows ?? const [])
        .whereType<Map>()
        .map((e) => WorkerProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    access = response['access'] is Map
        ? Map<String, dynamic>.from(response['access'])
        : {};
  }
}

class ProfileController extends BaseController {
  ProfileController(this.api);
  final EmployerApiService api;
  EmployerProfile? profile;
  Future<void> load() async => profile = await run(api.profile);
  Future<bool> save(Json values) async {
    final value = await run(() => api.updateProfile(values));
    if (value == null) return false;
    profile = value;
    return true;
  }
}
