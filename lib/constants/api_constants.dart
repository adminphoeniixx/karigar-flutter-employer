class ApiConstants {
  const ApiConstants._();

  static const baseUrl =
      'https://projects-karigar.rmsiry.easypanel.host/api/v1';

  static const otpSend = '/auth/otp/send';
  static const otpVerify = '/auth/otp/verify';
  static const me = '/auth/me';
  static const logout = '/auth/logout';
  static const account = '/account';
  static const locale = '/locale';
  static const reference = '/reference';
  static const cities = '/reference/cities';
  static const jobCategories = '/reference/job-categories';
  static const dashboard = '/employer/dashboard';
  static const profile = '/employer/profile';
  static const profileLogo = '/employer/profile/logo';
  static const jobs = '/employer/jobs';
  static const applicants = '/employer/applicants';
  static const workers = '/employer/workers';
  static const kyc = '/employer/kyc';
  static const notifications = '/notifications';
  static const notificationsReadAll = '/notifications/read-all';
  static const deviceTokens = '/device-tokens';
  static const reviews = '/employer/reviews';
  static const team = '/employer/team';
  static const conversations = '/conversations';
  static const plans = '/employer/plans';
  static const plansCallback = '/employer/plans/callback';
  static const creditsTopUp = '/employer/credits/top-up';
  static const creditsCallback = '/employer/credits/callback';
  static const preferences = '/preferences';
  static const sessions = '/auth/sessions';

  static String job(int id) => '$jobs/$id';
  static String closeJob(int id) => '${job(id)}/close';
  static String boostJob(int id) => '${job(id)}/boost';
  static String jobMatches(int id) => '${job(id)}/matches';
  static String inviteWorker(int id) => '${job(id)}/invite';
  static String jobApplicants(int id) => '${job(id)}/applicants';
  static String rescoreApplicants(int id) => '${job(id)}/rescore';
  static String applicant(int id) => '$applicants/$id';
  static String applicantStatus(int id) => '${applicant(id)}/status';
  static String applicantShortlist(int id) => '${applicant(id)}/shortlist';
  static String applicantUnlock(int id) => '${applicant(id)}/unlock';
  static String applicantReview(int id) => '${applicant(id)}/review';
  static String applicantInterview(int id) => '${applicant(id)}/interview';
  static String worker(int id) => '$workers/$id';
  static String notificationRead(String id) => '$notifications/$id/read';
  static String teamMember(int id) => '$team/$id';
  static String conversation(int id) => '$conversations/$id';
  static String conversationMessages(int id) => '${conversation(id)}/messages';
  static String conversationRead(int id) => '${conversation(id)}/read';
  static String subscribePlan(int id) => '$plans/$id/subscribe';
  static String session(int id) => '$sessions/$id';
}
