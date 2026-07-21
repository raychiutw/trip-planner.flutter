import 'package:url_launcher/url_launcher.dart';

final privacyPolicyUri = Uri.parse(
  'https://trip-planner-dby.pages.dev/privacy',
);

Future<void> openPrivacyPolicy() async {
  await launchUrl(privacyPolicyUri, mode: LaunchMode.externalApplication);
}
