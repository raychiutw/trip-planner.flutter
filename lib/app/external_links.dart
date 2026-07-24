import 'package:url_launcher/url_launcher.dart';

final privacyPolicyUri = Uri.parse(
  'https://trip-planner-dby.pages.dev/privacy',
);

final accountDeletionHelpUri = privacyPolicyUri.replace(
  fragment: 'delete-account',
);

Future<void> openPrivacyPolicy() async {
  await launchUrl(privacyPolicyUri, mode: LaunchMode.externalApplication);
}

Future<void> openAccountDeletionHelp() async {
  await launchUrl(accountDeletionHelpUri, mode: LaunchMode.externalApplication);
}
