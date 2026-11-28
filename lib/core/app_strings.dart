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
    'Karigar Database': 'कारीगर डेटाबेस',
    'Buy a database plan to see karigar numbers':
        'कारीगरों के नंबर देखने के लिए डेटाबेस प्लान लें',
    'Buy Database': 'डेटाबेस खरीदें',
    'Pending': 'बाकी',
    'Rejected': 'रिजेक्ट',
    'Interview': 'इंटरव्यू',
    'Withdrawn': 'वापस लिया',
    'MY JOBS': 'मेरी जॉब्स',
    'JOB LISTINGS': 'जॉब लिस्टिंग',
    'Review applicants and manage each posting.':
        'आवेदक देखें और हर जॉब संभालें।',
    'Applicants': 'आवेदक',
    'AI Interviews': 'AI इंटरव्यू',
    'AI Credits': 'AI क्रेडिट',
    'Paused': 'रुकी हुई',
    'Your plan has ended': 'आपका प्लान खत्म हो गया है',
    'Your jobs are hidden from karigars and closed to new applications.':
        'आपकी जॉब्स कारीगरों से छिपी हैं और नए आवेदन बंद हैं।',
    'Your plan has ended, so these jobs are paused: karigars can\'t see them or apply. Renew the plan to open them again.':
        'प्लान खत्म होने से ये जॉब्स रुकी हुई हैं: कारीगर इन्हें देख या इन पर आवेदन नहीं कर सकते। फिर से खोलने के लिए प्लान रिन्यू करें।',
    'Renew': 'रिन्यू करें',
    'Reject this applicant?': 'इस आवेदक को रिजेक्ट करें?',
    'They will be told they were not selected for this job.':
        'उन्हें बताया जाएगा कि इस जॉब के लिए उनका चयन नहीं हुआ।',
    'Reject': 'रिजेक्ट करें',
    'Close this job?': 'यह जॉब बंद करें?',
    'Karigars will no longer see it or apply. Its applicants stay in your list.':
        'कारीगर इसे नहीं देख पाएंगे और आवेदन नहीं कर पाएंगे। इसके आवेदक आपकी सूची में रहेंगे।',
    'Close job': 'जॉब बंद करें',
    'This device': 'यह डिवाइस',
    'Not used yet': 'अभी इस्तेमाल नहीं हुआ',
    'AI call finished': 'AI कॉल पूरी हुई',
    'KYC reviewed': 'KYC की जांच हुई',
    'New applicant': 'नया आवेदक',
    'New message': 'नया संदेश',
    'Job check': 'जॉब की जांच',
    'Job needs a check': 'जॉब की जांच ज़रूरी है',
    'Plan reminder': 'प्लान रिमाइंडर',
    'AI credits running low': 'AI क्रेडिट कम हो रहे हैं',
    'Interview reminder call': 'इंटरव्यू रिमाइंडर कॉल',
    'Interview reminder': 'इंटरव्यू रिमाइंडर',
    'Your business is verified. You can post jobs.':
        'आपका बिज़नेस सत्यापित है। आप जॉब पोस्ट कर सकते हैं।',
    'We are checking your documents. This usually takes a working day.':
        'हम आपके दस्तावेज़ जांच रहे हैं। इसमें आमतौर पर एक कामकाजी दिन लगता है।',
    'Business details': 'बिज़नेस की जानकारी',
    'Business type': 'बिज़नेस का प्रकार',
    'Legal name': 'कानूनी नाम',
    'GST number': 'GST नंबर',
    'Documents': 'दस्तावेज़',
    'Photo sent': 'फोटो भेजी गई',
    'To change these details, contact support.':
        'यह जानकारी बदलने के लिए सपोर्ट से संपर्क करें।',
    'We will tell you if anything needs fixing.':
        'कुछ ठीक करना हुआ तो हम आपको बताएंगे।',
    'Find Karigars': 'कारीगर खोजें',
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
    'Karigar Profile': 'कारीगर प्रोफाइल',
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
    'View matched karigars': 'मिलान वाले कारीगर देखें',
    'Matched karigars': 'मिलान वाले कारीगर',
    'Business Verification': 'बिज़नेस सत्यापन',
    'Pick from the list, or add your own title.':
        'सूची से चुनें, या अपना टाइटल जोड़ें।',
    'Other (not in the list)': 'अन्य (सूची में नहीं)',
    'Suggested from the job title. Change it if it is wrong.':
        'जॉब टाइटल से सुझाया गया। गलत हो तो बदल दें।',
    'Pick the closest craft, so the right karigars get this job.':
        'सबसे मिलता-जुलता काम चुनें, ताकि जॉब सही कारीगरों तक पहुँचे।',
    'Karigars find this job only by searching. If a craft comes close, pick that instead.':
        'यह जॉब कारीगरों को सिर्फ़ खोजने पर मिलेगी। कोई मिलता-जुलता काम हो तो वही चुनें।',
    'Pick a category, or Other if none fits.':
        'कैटेगरी चुनें, या कोई न मिले तो "अन्य"।',
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
    'Step {current} of {total}': 'चरण {current} / {total}',
    'Shortlist again': 'फिर से शॉर्टलिस्ट करें',
    'Use another number': 'दूसरा नंबर इस्तेमाल करें',
    'Choose your business type above to see the documents you need.':
        'ज़रूरी दस्तावेज़ देखने के लिए ऊपर बिज़नेस का प्रकार चुनें।',
    'Verify & Finish': 'वेरिफ़ाई करें और पूरा करें',
    'Our team checks your proofs.': 'हमारी टीम आपके प्रमाण जांचती है।',
    'A GST number or the business PAN is enough.':
        'GST नंबर या बिज़नेस PAN, कोई एक काफ़ी है।',
    'Enter a GST number or the business PAN.': 'GST नंबर या बिज़नेस PAN डालें।',
    'Select the type of work.': 'काम का प्रकार चुनें।',
    'Select at least one skill you hire for.':
        'कम से कम एक हुनर चुनें जिसके लिए आप रखते हैं।',
    'Shortlist': 'शॉर्टलिस्ट करें',
    'This takes the rejection back. They will be told they are shortlisted.':
        'इससे रिजेक्शन वापस हो जाएगा। कारीगर को बताया जाएगा कि वे शॉर्टलिस्ट हैं।',
    'Work & pay': 'काम और वेतन',
    'Karigar profile': 'कारीगर प्रोफ़ाइल',
    'Shift & interview': 'शिफ़्ट और इंटरव्यू',
    'Preview & publish': 'प्रीव्यू और पोस्ट',
    'Leave without saving?': 'बिना सेव किए बाहर जाएं?',
    'Your changes will be lost. Save a draft to finish it later.':
        'आपके बदलाव मिट जाएंगे। बाद में पूरा करने के लिए ड्राफ्ट सेव करें।',
    'Your changes to this job will be lost.':
        'इस जॉब में किए गए बदलाव मिट जाएंगे।',
    'Keep editing': 'बदलाव जारी रखें',
    'Save draft': 'ड्राफ्ट सेव करें',
    'Leave without saving': 'बिना सेव किए बाहर जाएं',
  };

  // Hinglish keeps familiar business terms in English and presents common app
  // actions in Roman Hindi. Text without a curated equivalent stays English,
  // so changing language never makes an action harder to understand.
  static const _hinglish = <String, String>{
    'No internet connection. Check your internet and try again.':
        'Internet nahi hai. Internet check karke dobara koshish karein.',
    'Post a job — reach karigars near you instantly':
        'Job post karein — paas ke karigars tak turant pahunchein',
    'Post your job and reach thousands of work-ready karigars near you. Talk to them directly — no middlemen.':
        'Apni job post karein aur paas ke hazaron karigars tak pahunchein. Unse seedhe baat karein — koi middleman nahi.',
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
    'Log out?': 'Log out karein?',
    'AI credit history': 'AI credit history',
    'Credits added and spent on AI calls':
        'AI calls par jude aur kharch hue credits',
    'You will need an OTP to log in again.':
        'Dobara login karne ke liye OTP lagega.',
    'Home': 'Home',
    'Post': 'Post karein',
    'Karigars': 'Karigar',
    'Profile': 'Profile',
    'Find Karigars': 'Karigar khojein',
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
    'Shortlisted Karigars': 'Shortlist kiye karigar',
    'Reviews & Ratings': 'Reviews aur ratings',
    'Plans & Karigar Database': 'Plans aur karigar database',
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
    'Get notified about karigar messages': 'कारीगर के संदेशों की सूचना पाएं',
    'Account & Security': 'खाता और सुरक्षा',
    'Login & security': 'लॉगिन और सुरक्षा',
    'OTP · device sessions': 'OTP · डिवाइस सेशन',
    'Team members': 'टीम सदस्य',
    'Add recruiters to your account': 'अपने खाते में रिक्रूटर जोड़ें',
    'Terms & Privacy': 'नियम और गोपनीयता',
    'Help & Support': 'मदद और सहायता',
    'Log out': 'लॉग आउट',
    'Log out?': 'लॉग आउट करें?',
    'AI credit history': 'AI क्रेडिट का हिसाब',
    'Credits added and spent on AI calls':
        'AI कॉल पर जुड़े और खर्च हुए क्रेडिट',
    'You will need an OTP to log in again.':
        'दोबारा लॉगिन करने के लिए OTP लगेगा।',
    'Super Karigar Employer · v1.0.0': 'सुपर कारीगर एम्प्लॉयर · v1.0.0',
    'Home': 'होम',
    'Post': 'पोस्ट करें',
    'Karigars': 'कारीगर',
    'Profile': 'प्रोफाइल',
    'Welcome back 👋': 'वापस आने पर स्वागत है 👋',
    'Active Jobs': 'चालू जॉब्स',
    'Total Applicants': 'कुल आवेदक',
    'Shortlisted': 'शॉर्टलिस्टेड',
    'Hired': 'नियुक्त',
    'Recent applicants': 'हाल के आवेदक',
    'Your active jobs': 'आपकी चालू जॉब्स',
    'Hiring today?': 'आज भर्ती करनी है?',
    'Post a job — reach karigars near you instantly':
        'जॉब पोस्ट करें — पास के कारीगरों तक तुरंत पहुंचें',
    'No internet connection. Check your internet and try again.':
        'इंटरनेट कनेक्शन नहीं है। इंटरनेट जांचें और फिर कोशिश करें।',
    'Post your job and reach thousands of work-ready karigars near you. Talk to them directly — no middlemen.':
        'अपनी जॉब पोस्ट करें और पास के हज़ारों काम के लिए तैयार कारीगरों तक पहुंचें। उनसे सीधे बात करें — कोई बिचौलिया नहीं।',
    'Post Job': 'जॉब पोस्ट करें',
    'Retry': 'फिर कोशिश करें',
    'Buy': 'खरीदें',
    'Verify': 'सत्यापित करें',
    'See all →': 'सभी देखें →',
    'Hire': 'नियुक्त करें',
    'Contact unlocked.': 'संपर्क अनलॉक हो गया।',
    'Applicant shortlisted.': 'आवेदक शॉर्टलिस्ट हो गया।',
    'Hire applicant?': 'आवेदक को नियुक्त करें?',
    'The karigar will receive your hire offer.':
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
    'Shortlisted Karigars': 'शॉर्टलिस्ट किए कारीगर',
    'Reviews & Ratings': 'रेटिंग और समीक्षा',
    'At workplace / Site': 'कार्यस्थल / साइट पर',
    'Work from home': 'घर से काम',
    'Both (Site & Home)': 'दोनों (साइट और घर)',
    'Interview in person': 'आमने-सामने इंटरव्यू',
    'Interview on phone / video': 'फ़ोन / वीडियो पर इंटरव्यू',
    'Interview in person or on phone / video':
        'आमने-सामने या फ़ोन / वीडियो पर इंटरव्यू',
    'Strong match': 'बहुत अच्छा मेल',
    'Good match': 'अच्छा मेल',
    'Maybe': 'शायद',
    'Weak match': 'कम मेल',
    'AI match': 'AI मेल',
    'monthly': 'महीना',
    'daily': 'दिन',
    'weekly': 'हफ़्ता',
    'hourly': 'घंटा',
    'month': 'महीना',
    'day': 'दिन',
    'Not disclosed': 'नहीं बताया',
    '{count} opening': '{count} पद',
    '{count} openings': '{count} पद',
    'Performance': 'प्रदर्शन',
    'Views': 'देखा गया',
    'Applied': 'आवेदन किया',
    'AI shortlist from database': 'डेटाबेस से AI शॉर्टलिस्ट',
    'Everyone who reached each step. A hired karigar also counts as shortlisted.':
        'हर चरण तक पहुंचे सभी लोग। नियुक्त कारीगर शॉर्टलिस्ट में भी गिना जाता है।',
    'Draft': 'ड्राफ्ट',
    'AI screening call': 'AI स्क्रीनिंग कॉल',
    'View conversation': 'बातचीत देखें',
    'Monthly pay looks too high. Check the amount.':
        'मासिक वेतन बहुत ज़्यादा लग रहा है। राशि जांचें।',
    'Tap the map to move the pin': 'पिन हटाने के लिए मैप पर टैप करें',
    'Pin set for this work location. Tap the map to move it.':
        'काम की जगह का पिन लग गया। बदलने के लिए मैप पर टैप करें।',
    'Pick the state and city, then tap the map on the exact spot.':
        'राज्य और शहर चुनें, फिर मैप पर सही जगह टैप करें।',
    'Chat': 'चैट',
    'Phone call': 'फ़ोन कॉल',
    'In-app message': 'ऐप में संदेश',
    'Quick message': 'तुरंत संदेश',
    'Offer sent': 'प्रस्ताव भेजा गया',
    'Interested': 'रुचि है',
    'Completed': 'पूरा हुआ',
    'Dialing': 'कॉल लग रही है',
    'Not interested': 'रुचि नहीं',
    'Unlock contact': 'संपर्क अनलॉक करें',
    'Industry *': 'उद्योग *',
    'Remove': 'हटाएं',
    'Skills': 'कौशल',
  };
}

extension AppStringsContext on BuildContext {
  String tr(String source) => AppStrings.text(this, source);

  /// [tr] with `{name}` placeholders filled in after translating.
  String trArgs(String source, Map<String, String> values) {
    var text = tr(source);
    values.forEach((key, value) => text = text.replaceAll('{$key}', value));
    return text;
  }

  /// The server's pay line ("₹23,400 – ₹28,600 / monthly") with its period
  /// word translated; the server always answers in English.
  String trWage(String label) => label
      .replaceAllMapped(
        RegExp(r'/ (monthly|daily|weekly|hourly|month|day)$'),
        (m) => '/ ${tr(m[1]!)}',
      )
      .replaceFirst('Not disclosed', tr('Not disclosed'));

  /// "1 opening", "3 openings", translated.
  String trOpenings(int count) => trArgs(
    count == 1 ? '{count} opening' : '{count} openings',
    {'count': '$count'},
  );
}
