import 'package:flutter/widgets.dart';
import '../l10n/worker_translations.dart';
import 'app_scope.dart';

/// UI translations for employer-facing, fixed app labels. Dynamic API data
/// (jobs, names, skills) is intentionally left untouched.
class AppStrings {
  const AppStrings._();

  static String text(BuildContext context, String source) {
    final language =
        AppScope.maybeOf(context)?.appLanguage.locale.languageCode ??
        Localizations.localeOf(context).languageCode;
    if (language == 'en') return source;
    if (language == 'hinglish') return _hinglish[source] ?? source;
    // Reuse the complete, proven catalogue used in the worker app, then let
    // employer-only copy override it.
    return _employerHi[source] ??
        _hi[source] ??
        translateAppText(source, language);
  }

  static const _employerHi = <String, String>{
    'Find Workers': 'कारीगर खोजें',
    'Find karigars': 'कारीगर खोजें',
    'Database contacts': 'डेटाबेस संपर्क',
    'Applicant contacts': 'आवेदक संपर्क',
    'Search skill, trade, name...': 'कौशल, काम या नाम खोजें...',
    'All': 'सभी',
    'Apply': 'लागू करें',
    'Apply filters': 'फ़िल्टर लागू करें',
    'Clear filters': 'फ़िल्टर साफ़ करें',
    'Reset': 'रीसेट करें',
    'Contact locked · view profile for plan access':
        'संपर्क लॉक है · प्लान एक्सेस के लिए प्रोफाइल देखें',
    'Worker Profile': 'कारीगर प्रोफाइल',
    'Messages': 'संदेश',
    'Message': 'संदेश',
    'Notifications': 'सूचनाएं',
    'No notifications yet': 'अभी कोई सूचना नहीं है',
    'Mark all read': 'सभी को पढ़ा हुआ करें',
    'No conversations yet': 'अभी कोई बातचीत नहीं है',
    'Start the conversation from an applicant profile.':
        'आवेदक प्रोफाइल से बातचीत शुरू करें।',
    'My Jobs': 'मेरी जॉब्स',
    'Manage Job': 'जॉब प्रबंधित करें',
    'Edit job': 'जॉब बदलें',
    'Save as draft': 'ड्राफ्ट सेव करें',
    'View matched workers': 'मिलान वाले कारीगर देखें',
    'Matched workers': 'मिलान वाले कारीगर',
    'Business Verification': 'बिज़नेस सत्यापन',
    'Business verification required': 'बिज़नेस सत्यापन आवश्यक है',
    'Verify business': 'बिज़नेस सत्यापित करें',
    'Submit your details for review.': 'समीक्षा के लिए अपनी जानकारी भेजें।',
    'Set up your business': 'अपना बिज़नेस सेट करें',
    'Business name and contact person are required.':
        'बिज़नेस का नाम और संपर्क व्यक्ति आवश्यक हैं।',
    'See plans': 'प्लान देखें',
    'View plans': 'प्लान देखें',
    'View plans to access contacts': 'संपर्क पाने के लिए प्लान देखें',
    'Continue': 'जारी रखें',
    'Continue to payment': 'भुगतान जारी रखें',
    'Confirm payment': 'भुगतान की पुष्टि करें',
    'Payment successful.': 'भुगतान सफल रहा।',
    'No contact unlocks left': 'कोई संपर्क अनलॉक शेष नहीं है',
    'Billing profile': 'बिलिंग प्रोफाइल',
    'Tax invoice': 'टैक्स इनवॉइस',
    'Invoice saved.': 'इनवॉइस सेव हो गया।',
    'Reviews': 'समीक्षाएं',
    'No reviews yet': 'अभी कोई समीक्षा नहीं है',
    'Team members': 'टीम सदस्य',
    'Add team member': 'टीम सदस्य जोड़ें',
    'Add': 'जोड़ें',
    'Login & security': 'लॉगिन और सुरक्षा',
    'Sign out': 'साइन आउट',
    'Get Started': 'शुरू करें',
    'Skip for now': 'अभी छोड़ें',
    'Phone number copied.': 'फोन नंबर कॉपी हो गया।',
    'Copy phone': 'फोन कॉपी करें',
    'Copy share link': 'शेयर लिंक कॉपी करें',
    'WhatsApp': 'व्हाट्सऐप',
    'Call': 'कॉल करें',
    'Call & schedule': 'कॉल और शेड्यूल करें',
    'Cancel interview': 'इंटरव्यू रद्द करें',
    'Confirm interview': 'इंटरव्यू की पुष्टि करें',
    'No screening calls yet.': 'अभी कोई स्क्रीनिंग कॉल नहीं है।',
    'AI screening calls': 'AI स्क्रीनिंग कॉल',
    'Recommended': 'सुझाया गया',
    'Change': 'बदलें',
    'Email': 'ईमेल',
    'Later': 'बाद में',
    'Load more': 'और दिखाएं',
  };

  // Hinglish keeps familiar business terms in English and presents common app
  // actions in Roman Hindi. Text without a curated equivalent stays English,
  // so changing language never makes an action harder to understand.
  static const _hinglish = <String, String>{
    'Settings': 'Settings',
    'Preferences': 'Pasand',
    'Language': 'Bhasha',
    'Choose language': 'Bhasha chunein',
    'Dark theme': 'Dark theme',
    'Applicant alerts': 'Applicant alerts',
    'Message alerts': 'Message alerts',
    'Account & Security': 'Account aur security',
    'Login & security': 'Login aur security',
    'Help & Support': 'Madad aur support',
    'Log out': 'Log out',
    'Home': 'Home',
    'Post': 'Post karein',
    'Workers': 'Karigar',
    'Profile': 'Profile',
    'Find Workers': 'Karigar khojein',
    'Find karigars': 'Karigar khojein',
    'Search skill, trade, name...': 'Skill, kaam ya naam khojein...',
    'All': 'Sabhi',
    'Apply': 'Laagu karein',
    'Apply filters': 'Filters laagu karein',
    'Clear filters': 'Filters hataein',
    'My Jobs': 'Meri jobs',
    'Post Job': 'Job post karein',
    'Business Profile': 'Business profile',
    'Edit Business Profile': 'Business profile badlein',
    'Shortlisted Workers': 'Shortlist kiye karigar',
    'Reviews & Ratings': 'Reviews aur ratings',
    'Plans & Worker Database': 'Plans aur worker database',
    'Order History': 'Order history',
    'Invoices': 'Invoices',
    'Retry': 'Dobara try karein',
    'Save': 'Save karein',
    'Cancel': 'Cancel',
    'Continue': 'Aage badhein',
  };

  static const _hi = <String, String>{
    'Settings': 'सेटिंग्स',
    'Preferences': 'पसंद',
    'Language': 'भाषा',
    'Choose language': 'भाषा चुनें',
    'Dark theme': 'डार्क थीम',
    'Switch to a darker screen': 'गहरी रंग वाली स्क्रीन इस्तेमाल करें',
    'Applicant alerts': 'आवेदक सूचनाएं',
    'Get notified on new applications': 'नए आवेदनों की सूचना पाएं',
    'Message alerts': 'संदेश सूचनाएं',
    'Get notified about worker messages': 'कारीगर के संदेशों की सूचना पाएं',
    'Account & Security': 'खाता और सुरक्षा',
    'Login & security': 'लॉगिन और सुरक्षा',
    'OTP · device sessions': 'OTP · डिवाइस सेशन',
    'Team members': 'टीम सदस्य',
    'Add recruiters to your account': 'अपने खाते में रिक्रूटर जोड़ें',
    'Terms & Privacy': 'नियम और गोपनीयता',
    'Help & Support': 'मदद और सहायता',
    'Log out': 'लॉग आउट',
    'Super Karigar Employer · v1.0.0': 'सुपर कारीगर एम्प्लॉयर · v1.0.0',
    'Home': 'होम',
    'Post': 'पोस्ट करें',
    'Workers': 'कारीगर',
    'Profile': 'प्रोफाइल',
    'Welcome back 👋': 'वापस आने पर स्वागत है 👋',
    'Active Jobs': 'चालू जॉब्स',
    'Total Applicants': 'कुल आवेदक',
    'Shortlisted': 'शॉर्टलिस्टेड',
    'Hired': 'नियुक्त',
    'Recent applicants': 'हाल के आवेदक',
    'Your active jobs': 'आपकी चालू जॉब्स',
    'Hiring today?': 'आज भर्ती करनी है?',
    'Post a job free — reach workers instantly':
        'मुफ्त जॉब पोस्ट करें — कारीगरों तक तुरंत पहुंचें',
    'Post Job': 'जॉब पोस्ट करें',
    'Retry': 'फिर कोशिश करें',
    'Buy': 'खरीदें',
    'Verify': 'सत्यापित करें',
    'See all →': 'सभी देखें →',
    'Hire': 'नियुक्त करें',
    'Contact unlocked.': 'संपर्क अनलॉक हो गया।',
    'Applicant shortlisted.': 'आवेदक शॉर्टलिस्ट हो गया।',
    'Hire applicant?': 'आवेदक को नियुक्त करें?',
    'The worker will receive your hire offer.':
        'कारीगर को आपका नियुक्ति प्रस्ताव मिलेगा।',
    'Cancel': 'रद्द करें',
    'Send offer': 'प्रस्ताव भेजें',
    'My Jobs': 'मेरी जॉब्स',
    'Active': 'चालू',
    'Closed': 'बंद',
    'Drafts': 'ड्राफ्ट',
    'Business Profile': 'बिज़नेस प्रोफाइल',
    'Edit Business Profile': 'बिज़नेस प्रोफाइल बदलें',
    'Business Verification': 'बिज़नेस सत्यापन',
    'Shortlisted Workers': 'शॉर्टलिस्ट किए कारीगर',
    'Reviews & Ratings': 'रेटिंग और समीक्षा',
  };
}

extension AppStringsContext on BuildContext {
  String tr(String source) => AppStrings.text(this, source);
}
